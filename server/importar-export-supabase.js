import { DatabaseSync } from 'node:sqlite';
import { randomBytes, scryptSync } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { abrirBase } from './database.js';

// Importa un JSON exportado desde Supabase > Table Editor. No usa credenciales remotas.
const archivo = process.argv[2];
if (!archivo) throw new Error('Uso: node importar-export-supabase.js <exportacion.json>');
const datos = JSON.parse(readFileSync(archivo, 'utf8'));
const db = abrirBase(process.env.DATABASE_PATH || './vetlink.sqlite');
const tablas = {
  cuentas: ['id', 'email', 'nombre', 'password', 'verificada', 'activa', 'administrador_tecnico'],
  granjas: ['id', 'nombre', 'hectareas', 'trabajadores', 'codigo', 'runsa', 'documentos_terreno', 'confirmada'],
  vinculaciones: ['id', 'granja_id', 'cuenta_id', 'rol', 'activa'],
  invitaciones: ['id', 'granja_id', 'correo', 'rol', 'vigente', 'aceptada', 'enviada_en'],
  fichas_bovinas: ['id', 'granja_id', 'nombre', 'identificacion', 'etapa', 'raza', 'nacimiento', 'nacimiento_estimado', 'fecha_baja', 'motivo_baja'],
  atenciones_clinicas: ['id', 'ficha_id', 'registrado_por', 'fecha', 'tipo', 'detalle', 'anulado'],
  eventos_reproductivos: ['id', 'ficha_id', 'registrado_por', 'fecha', 'tipo', 'aptitud', 'prenez', 'proximo_control', 'parto_probable', 'numero_parto', 'detalle', 'anulado'],
  tratamientos: ['id', 'ficha_id', 'atencion_id', 'prescrito_por', 'medicamento', 'dosis', 'unidad', 'via', 'frecuencia', 'inicio', 'duracion', 'fecha_fin', 'motivo_fin', 'anulado'],
  prevenciones: ['id', 'ficha_id', 'programado_por', 'tipo', 'nombre', 'fecha_programada', 'estado'],
  aplicaciones: ['id', 'ficha_id', 'aplicado_por', 'tratamiento_id', 'prevencion_id', 'fecha_hora_real', 'dosis', 'unidad', 'observacion', 'anulado'],
};
const cuentaRows = datos.cuentas || [];
function migrar() {
  db.exec('BEGIN IMMEDIATE');
  const totales = {};
  try {
  for (const [tabla, columnas] of Object.entries(tablas)) {
    const filas = datos[tabla] || [];
    totales[tabla] = 0;
    for (const original of filas) {
      const fila = { ...original };
      if (tabla === 'cuentas') {
        fila.email ??= fila.identificador;
        fila.nombre ??= fila.email;
        if (!fila.password) {
          const sal = randomBytes(24).toString('hex');
          fila.password = `${sal}:${scryptSync(randomBytes(32).toString('hex'), sal, 64).toString('hex')}`;
        }
        // Las contraseñas de Supabase no se exportan: los usuarios tendrán que verificar y elegir una nueva.
        fila.verificada = 0;
      }
      if (tabla === 'granjas') fila.documentos_terreno ??= '';
      if (tabla === 'prevenciones') fila.ficha_id ??= fila.animal_id;
      const campos = columnas.filter((columna) => fila[columna] !== undefined && fila[columna] !== null);
      const valores = campos.map((columna) => typeof fila[columna] === 'boolean' ? Number(fila[columna]) : fila[columna]);
      if (tabla === 'cuentas' && !campos.includes('activa')) { campos.push('activa'); valores.push(1); }
      if (tabla === 'cuentas' && !campos.includes('administrador_tecnico')) { campos.push('administrador_tecnico'); valores.push(0); }
      const placeholders = campos.map(() => '?').join(',');
      const result = db.prepare(`INSERT OR IGNORE INTO ${tabla} (${campos.join(',')}) VALUES (${placeholders})`).run(...valores);
      totales[tabla] += result.changes;
    }
  }
    db.exec('COMMIT');
    return totales;
  } catch (error) {
    db.exec('ROLLBACK');
    throw error;
  }
}
try {
  const resumen = migrar();
  console.log('Importación completada. Filas nuevas por tabla:');
  for (const [tabla, cantidad] of Object.entries(resumen)) console.log(`${tabla}: ${cantidad}`);
  console.log(`Cuentas importadas (${cuentaRows.length}) quedan pendientes de verificación; reenviarles confirmación desde Swagger.`);
} finally { db.close(); }
