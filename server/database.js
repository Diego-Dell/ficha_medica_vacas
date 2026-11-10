import { DatabaseSync } from 'node:sqlite';

export function abrirBase(path) {
  const db = new DatabaseSync(path);
  db.exec(`
    PRAGMA foreign_keys = ON;
    PRAGMA journal_mode = WAL;
    CREATE TABLE IF NOT EXISTS cuentas (
      id TEXT PRIMARY KEY, email TEXT NOT NULL UNIQUE, nombre TEXT NOT NULL,
      password TEXT NOT NULL, verificada INTEGER NOT NULL DEFAULT 0,
      activa INTEGER NOT NULL DEFAULT 1, administrador_tecnico INTEGER NOT NULL DEFAULT 0
    );
    CREATE TABLE IF NOT EXISTS sesiones (
      token TEXT PRIMARY KEY, cuenta_id TEXT NOT NULL REFERENCES cuentas(id), vence INTEGER NOT NULL
    );
    CREATE TABLE IF NOT EXISTS enlaces (
      token TEXT PRIMARY KEY, cuenta_id TEXT NOT NULL REFERENCES cuentas(id),
      tipo TEXT NOT NULL, vence INTEGER NOT NULL
    );
    CREATE TABLE IF NOT EXISTS granjas (
      id TEXT PRIMARY KEY, nombre TEXT NOT NULL, hectareas REAL NOT NULL,
      trabajadores INTEGER NOT NULL DEFAULT 0, codigo TEXT UNIQUE,
      runsa TEXT NOT NULL, documentos_terreno TEXT NOT NULL, confirmada INTEGER NOT NULL DEFAULT 0
    );
    CREATE TABLE IF NOT EXISTS vinculaciones (
      id TEXT PRIMARY KEY, granja_id TEXT NOT NULL REFERENCES granjas(id),
      cuenta_id TEXT NOT NULL REFERENCES cuentas(id), rol TEXT NOT NULL CHECK(rol IN ('dueno','veterinario','trabajador')),
      activa INTEGER NOT NULL DEFAULT 1, UNIQUE(granja_id, cuenta_id)
    );
    CREATE TABLE IF NOT EXISTS invitaciones (
      id TEXT PRIMARY KEY, granja_id TEXT NOT NULL REFERENCES granjas(id), correo TEXT NOT NULL,
      rol TEXT NOT NULL CHECK(rol IN ('veterinario','trabajador')),
      vigente INTEGER NOT NULL DEFAULT 1, aceptada INTEGER NOT NULL DEFAULT 0, enviada_en TEXT NOT NULL
    );
    CREATE UNIQUE INDEX IF NOT EXISTS invitacion_pendiente ON invitaciones(granja_id, correo)
      WHERE vigente = 1 AND aceptada = 0;
    CREATE TABLE IF NOT EXISTS fichas_bovinas (
      id TEXT PRIMARY KEY, granja_id TEXT NOT NULL REFERENCES granjas(id), nombre TEXT,
      identificacion TEXT NOT NULL, etapa TEXT NOT NULL, raza TEXT,
      fecha_baja TEXT, motivo_baja TEXT
    );
    CREATE TABLE IF NOT EXISTS prevenciones (
      id TEXT PRIMARY KEY, ficha_id TEXT NOT NULL REFERENCES fichas_bovinas(id),
      animal_id TEXT REFERENCES fichas_bovinas(id), programado_por TEXT REFERENCES cuentas(id), tipo TEXT NOT NULL DEFAULT 'control',
      nombre TEXT NOT NULL DEFAULT 'Control', estado TEXT NOT NULL DEFAULT 'pendiente',
      fecha_programada TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS atenciones_clinicas (
      id TEXT PRIMARY KEY, ficha_id TEXT NOT NULL REFERENCES fichas_bovinas(id),
      registrado_por TEXT NOT NULL REFERENCES cuentas(id), fecha TEXT NOT NULL,
      tipo TEXT NOT NULL, detalle TEXT, anulado INTEGER NOT NULL DEFAULT 0
    );
    CREATE TABLE IF NOT EXISTS eventos_reproductivos (
      id TEXT PRIMARY KEY, ficha_id TEXT NOT NULL REFERENCES fichas_bovinas(id),
      registrado_por TEXT NOT NULL REFERENCES cuentas(id), fecha TEXT NOT NULL,
      tipo TEXT NOT NULL, aptitud TEXT, prenez TEXT, proximo_control TEXT,
      parto_probable TEXT, numero_parto INTEGER, detalle TEXT, anulado INTEGER NOT NULL DEFAULT 0
    );
    CREATE TABLE IF NOT EXISTS tratamientos (
      id TEXT PRIMARY KEY, ficha_id TEXT NOT NULL REFERENCES fichas_bovinas(id),
      atencion_id TEXT REFERENCES atenciones_clinicas(id), prescrito_por TEXT NOT NULL REFERENCES cuentas(id),
      medicamento TEXT NOT NULL, dosis REAL, unidad TEXT, via TEXT, frecuencia TEXT,
      inicio TEXT NOT NULL, duracion TEXT, fecha_fin TEXT, motivo_fin TEXT,
      anulado INTEGER NOT NULL DEFAULT 0
    );
    CREATE TABLE IF NOT EXISTS aplicaciones (
      id TEXT PRIMARY KEY, ficha_id TEXT NOT NULL REFERENCES fichas_bovinas(id),
      aplicado_por TEXT NOT NULL REFERENCES cuentas(id), tratamiento_id TEXT REFERENCES tratamientos(id),
      prevencion_id TEXT REFERENCES prevenciones(id), fecha_hora_real TEXT NOT NULL,
      dosis REAL, unidad TEXT, observacion TEXT, anulado INTEGER NOT NULL DEFAULT 0
    );
  `);
  const asegurarColumna = (tabla, nombre, definicion) => {
    const columnas = db.prepare(`PRAGMA table_info(${tabla})`).all();
    if (!columnas.some((columna) => columna.name === nombre)) db.exec(`ALTER TABLE ${tabla} ADD COLUMN ${nombre} ${definicion}`);
  };
  asegurarColumna('cuentas', 'activa', 'INTEGER NOT NULL DEFAULT 1');
  asegurarColumna('cuentas', 'administrador_tecnico', 'INTEGER NOT NULL DEFAULT 0');
  asegurarColumna('granjas', 'trabajadores', 'INTEGER NOT NULL DEFAULT 0');
  asegurarColumna('granjas', 'codigo', 'TEXT');
  asegurarColumna('fichas_bovinas', 'nacimiento', 'TEXT');
  asegurarColumna('fichas_bovinas', 'nacimiento_estimado', 'INTEGER NOT NULL DEFAULT 0');
  asegurarColumna('prevenciones', 'ficha_id', 'TEXT');
  asegurarColumna('prevenciones', 'programado_por', 'TEXT');
  asegurarColumna('prevenciones', 'tipo', "TEXT NOT NULL DEFAULT 'control'");
  asegurarColumna('prevenciones', 'nombre', "TEXT NOT NULL DEFAULT 'Control'");
  try { db.exec('UPDATE prevenciones SET ficha_id = animal_id WHERE ficha_id IS NULL'); } catch { /* nueva tabla sin filas legacy */ }
  return db;
}
