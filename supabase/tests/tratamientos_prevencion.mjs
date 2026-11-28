// PostgreSQL en memoria: no conecta a Supabase ni crea una base de datos en disco.
// Requiere @electric-sql/pglite; ejecutar con Node desde la raíz del proyecto.
import { PGlite } from '@electric-sql/pglite';
import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';

const db = new PGlite();
await db.exec(`
  create role anon; create role authenticated;
  create schema auth;
  create function auth.uid() returns uuid language sql as
    $$ select nullif(current_setting('request.jwt.claim.sub', true),'')::uuid $$;
  create table cuentas(id uuid primary key, activa boolean default true);
  create table granjas(id uuid primary key, confirmada boolean default true);
  create table vinculaciones(cuenta_id uuid, granja_id uuid, rol text, activa boolean default true);
  create table fichas_bovinas(id uuid primary key, granja_id uuid, fecha_baja date);
  create table atenciones_clinicas(id uuid primary key, ficha_id uuid, fecha timestamptz, anulado boolean default false);
  create table tratamientos(id uuid primary key default gen_random_uuid(), ficha_id uuid not null,
    atencion_id uuid not null, prescrito_por uuid not null, medicamento text not null,
    dosis numeric(10,3), unidad text, via text, frecuencia text, inicio date, duracion text,
    fecha_fin date, motivo_fin text, anulado boolean default false, version integer default 1);
  create type tipo_prevencion as enum ('vacuna','desparasitacion','control');
  create type estado_prevencion as enum ('pendiente','realizada','cancelada');
  create table prevenciones(id uuid primary key default gen_random_uuid(), ficha_id uuid, programado_por uuid,
    tipo tipo_prevencion, nombre text, fecha_programada date, estado estado_prevencion default 'pendiente',
    fecha_realizacion timestamptz, version integer default 1);
  create table aplicaciones(id uuid primary key default gen_random_uuid(), ficha_id uuid,
    tratamiento_id uuid, prevencion_id uuid, fecha_hora_real timestamptz default now(), anulado boolean default false);
  alter table tratamientos enable row level security;
  alter table prevenciones enable row level security;
  grant usage on schema public, auth to authenticated;
  grant select on cuentas, granjas, vinculaciones, fichas_bovinas to authenticated;
`);
await db.exec(await readFile(new URL('../migrations/202611220002_tratamientos_prevencion.sql', import.meta.url), 'utf8'));

const vet = '00000000-0000-0000-0000-000000000001';
const worker = '00000000-0000-0000-0000-000000000002';
const farm = '00000000-0000-0000-0000-000000000003';
const animal = '00000000-0000-0000-0000-000000000004';
const other = '00000000-0000-0000-0000-000000000005';
const attention = '00000000-0000-0000-0000-000000000006';
await db.exec(`insert into cuentas values ('${vet}',true),('${worker}',true);
  insert into granjas values ('${farm}',true);
  insert into vinculaciones values ('${vet}','${farm}','veterinario',true),('${worker}','${farm}','trabajador',true);
  insert into fichas_bovinas values ('${animal}','${farm}',null),('${other}','${farm}',null);
  insert into atenciones_clinicas values ('${attention}','${animal}',now()-interval '2 days',false);`);
const session = async (user) => db.query("select set_config('request.jwt.claim.sub',$1,false)", [user]);
const value = async (sql, params = []) => (await db.query(sql, params)).rows[0].value;
const today = await value("select (now() at time zone 'America/La_Paz')::date::text as value");
const data = { medicamento: 'Indicación A', dosis: 2.5, unidad: 'mL', via: 'Vía de prueba',
  frecuencia: 'Cada 12 horas', inicio: today, duracion: '3 días', retiro: 'Retiro de prueba' };
let passed = 0;
async function rejects(sql, params, pattern) {
  await assert.rejects(() => db.query(sql, params), pattern); passed++;
}
const create = (params, previous = null, version = null, reason = null) => value(
  'select guardar_indicacion_tratamiento($1,$2,$3,$4,$5,$6,$7) as value',
  [animal, attention, params, previous, version, previous ? today : null, reason]);
await session(vet);
const original = await create(data);
assert.equal(await value('select retiro as value from tratamientos where id=$1', [original]), data.retiro); passed++;
await rejects('select guardar_indicacion_tratamiento($1,$2,$3)', [other, attention, data], /mismo animal/);
await rejects('update tratamientos set dosis=99 where id=$1', [original], /cerrá la anterior/);
const replacement = await create({ ...data, dosis: 1 }, original, 1, 'Cambio de indicación');
assert.equal(await value('select dosis::float as value from tratamientos where id=$1', [original]), 2.5); passed++;
assert.equal(await value('select motivo_fin as value from tratamientos where id=$1', [original]), 'Cambio de indicación'); passed++;
assert.equal(await value('select anterior_id as value from tratamientos where id=$1', [replacement]), original); passed++;
await rejects('select finalizar_indicacion_tratamiento($1,1,$2,$3)', [original, today, 'Otro cierre'], /indicación cambió/);
await rejects('select guardar_indicacion_tratamiento($1,$2,$3,$4,1,$5,$6)',
  [animal, attention, { ...data, dosis: -1 }, replacement, today, 'Inválido'], /dosis/);
assert.equal(await value('select fecha_fin as value from tratamientos where id=$1', [replacement]), null); passed++;
await db.exec(`create function fallar_insercion_prueba() returns trigger language plpgsql as $$
  begin if new.medicamento = 'Fallar al insertar' then raise exception 'Inserción simulada fallida'; end if; return new; end $$;
  create trigger fallar_insercion_prueba before insert on tratamientos for each row execute function fallar_insercion_prueba();`);
await assert.rejects(() => create({ ...data, medicamento: 'Fallar al insertar' }, replacement, 1, 'Cambio'), /simulada fallida/); passed++;
assert.equal(await value('select fecha_fin as value from tratamientos where id=$1', [replacement]), null); passed++;
await rejects('insert into aplicaciones(ficha_id,tratamiento_id) values($1,$2)', [animal, original], /ya no está vigente/);
await db.query('insert into aplicaciones(ficha_id,tratamiento_id) values($1,$2)', [animal, replacement]); passed++;
await db.query('select finalizar_indicacion_tratamiento($1,1,$2,$3)', [replacement, today, 'Completado']); passed++;
await rejects('delete from tratamientos where id=$1', [original], /conservan/);
await session(worker);
await rejects('select guardar_indicacion_tratamiento($1,$2,$3)', [animal, attention, data], /veterinario activo/);
await session(vet);
const control = await value("select programar_prevencion($1,'Control','Control de prueba',$2) as value", [animal, today]);
assert.equal(await value('select estado::text as value from prevenciones where id=$1', [control]), 'pendiente'); passed++;
await rejects('insert into aplicaciones(ficha_id,prevencion_id) values($1,$2)', [animal, control], /no admite aplicaciones/);
await db.query('select completar_control_preventivo($1,1,now())', [control]);
assert.equal(await value('select estado::text as value from prevenciones where id=$1', [control]), 'realizada'); passed++;
await rejects('select completar_control_preventivo($1,1,now())', [control], /control cambió/);
const vaccine = await value("select programar_prevencion($1,'Vacuna','Vacuna de prueba',$2) as value", [animal, today]);
await rejects('select completar_control_preventivo($1,1,now())', [vaccine], /control cambió/);
// EF Core puede actualizar la prevención antes de insertar la aplicación en la misma transacción.
await db.query("update prevenciones set estado='realizada', fecha_realizacion=now() where id=$1", [vaccine]);
await db.query('insert into aplicaciones(ficha_id,prevencion_id) values($1,$2)', [animal, vaccine]); passed++;
await db.query('update fichas_bovinas set fecha_baja=$1 where id=$2', [today, animal]);
await rejects('select programar_prevencion($1,$2,$3,$4)', [animal, 'Control', 'Baja', today], /ficha activa/);
await session(worker);
await db.exec('set role authenticated');
assert.equal(await value('select count(*)::int as value from tratamientos'), 2); passed++;
await db.exec('reset role');
await session(other);
await db.exec('set role authenticated');
assert.equal(await value('select count(*)::int as value from tratamientos'), 0); passed++;
await db.exec('reset role');
assert.equal(await value("select has_function_privilege('anon','public.programar_prevencion(uuid,text,text,date)','execute') as value"), false); passed++;
await db.close();
console.log(`${passed} comprobaciones PostgreSQL correctas (datos solo en memoria).`);
