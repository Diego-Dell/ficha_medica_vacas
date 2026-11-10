import { test } from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { abrirBase } from './database.js';
import { crearApp } from './app.js';
import { ApiError, mailgun } from './mailgun.js';

async function fixture(t) {
  const db = abrirBase(':memory:');
  const mensajes = [];
  let fallo = false;
  const app = crearApp({ db, publicUrl: 'http://localhost:3000', enviar: async (m) => {
    if (fallo) throw new ApiError(502, 'Mailgun rechazó el envío (HTTP 403)');
    mensajes.push(m);
  } });
  const server = app.listen(0, '127.0.0.1');
  await once(server, 'listening');
  const base = `http://127.0.0.1:${server.address().port}`;
  t.after(() => { server.closeAllConnections(); server.close(); db.close(); });
  async function pedir(path, datos, token) {
    const response = await fetch(base + path, {
      method: datos === undefined ? 'GET' : 'POST',
      redirect: 'manual',
      headers: { 'content-type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
      ...(datos === undefined ? {} : { body: JSON.stringify(datos) }),
    });
    const text = await response.text();
    const location = response.headers.get('location');
    return { status: response.status, ...(location ? { location } : {}), data: response.headers.get('content-type')?.includes('application/json') ? JSON.parse(text) : text };
  }
  async function cuenta(email, dueno = false) {
    const registro = await pedir('/auth/registro', { email, password: 'secreta1', data: { nombre: email,
      ...(dueno ? { granja: 'Los Pinos', superficie: 18, runsa: 'SC-01', documento: 'terreno.pdf' } : {}) } });
    assert.equal(registro.status, 201);
    const link = mensajes.at(-1).text.match(/http:\/\/\S+/)[0];
    const confirmacion = await pedir(new URL(link).pathname + new URL(link).search);
    assert.equal(confirmacion.status, 302);
    assert.equal(confirmacion.location, 'http://localhost:3000');
    const login = await pedir('/auth/login', { email, password: 'secreta1' });
    assert.equal(login.status, 200);
    return login.data.access_token;
  }
  return { db, mensajes, pedir, cuenta, base, fallar: (v) => { fallo = v; } };
}

test('flujo completo: dueño, ambos roles, fallo/reenvío, aislamiento y aceptación', async (t) => {
  const f = await fixture(t);
  const dueno = await f.cuenta('dueno@ejemplo.com', true);
  const otro = await f.cuenta('otro@ejemplo.com', true);
  const vet = await f.cuenta('vet@ejemplo.com');
  const trabajador = await f.cuenta('trabajador@ejemplo.com');
  const vinculos = await f.pedir('/vinculaciones', undefined, dueno);
  const granja = vinculos.data[0].granjas.id;
  assert.equal(vinculos.data[0].granjas.confirmada, false);
  assert.equal((await f.pedir('/invitaciones', { granja_id: granja, correo: 'vet@ejemplo.com', rol: 'veterinario' }, dueno)).status, 403);
  f.db.prepare('UPDATE granjas SET confirmada=1').run();
  assert.equal((await f.pedir('/vinculaciones')).status, 401);
  assert.equal((await f.pedir('/invitaciones', { granja_id: granja, correo: 'x@ejemplo.com', rol: 'dueno' }, dueno)).status, 400);
  assert.equal((await f.pedir('/invitaciones', { granja_id: granja, correo: 'x@ejemplo.com', rol: 'trabajador' }, otro)).status, 403);
  for (const [correo, rol, sesion] of [['vet@ejemplo.com', 'veterinario', vet], ['trabajador@ejemplo.com', 'trabajador', trabajador]]) {
    const datos = { granja_id: granja, correo, rol };
    const creado = await f.pedir('/invitaciones', datos, dueno);
    assert.equal(creado.status, 201);
    const id = creado.data.id;
    assert.equal((await f.pedir('/invitaciones', datos, dueno)).status, 409);
    assert.equal((await f.pedir('/dynamic-action', { invitacion_id: id }, otro)).status, 403);
    assert.equal((await f.pedir('/dynamic-action', { invitacion_id: id }, sesion)).status, 403);
    f.fallar(true);
    assert.equal((await f.pedir('/dynamic-action', { invitacion_id: id }, dueno)).status, 502);
    assert.equal(f.db.prepare('SELECT aceptada FROM invitaciones WHERE id=?').get(id).aceptada, 0);
    f.fallar(false);
    for (let intento = 0; intento < 2; intento++) {
      assert.deepEqual(await f.pedir('/dynamic-action', { invitacion_id: id, correo: 'atacante@ejemplo.com' }, dueno), { status: 200, data: { enviado: true } });
      assert.equal(f.mensajes.at(-1).to, correo);
      assert.match(f.mensajes.at(-1).text, new RegExp(rol));
      assert.match(f.mensajes.at(-1).text, /Me invitaron: crear cuenta/);
      assert.match(f.mensajes.at(-1).text, /confirma tu correo e inicia sesión/i);
    }
    assert.equal((await f.pedir('/aceptar_invitacion', { p_invitacion: id }, otro)).status, 403);
    const mias = await f.pedir('/invitaciones', undefined, sesion);
    assert.deepEqual(mias.data.map((i) => i.id), [id]);
    assert.equal((await f.pedir('/aceptar_invitacion', { p_invitacion: id }, sesion)).status, 200);
    assert.equal((await f.pedir('/aceptar_invitacion', { p_invitacion: id }, sesion)).status, 409);
    assert.equal((await f.pedir('/dynamic-action', { invitacion_id: id }, dueno)).status, 409);
    assert.equal((await f.pedir('/invitaciones', datos, dueno)).status, 409);
  }
  assert.equal(f.db.prepare('SELECT COUNT(*) n FROM invitaciones').get().n, 2);
  assert.equal((await f.pedir(`/granjas/${granja}/resumen`, undefined, vet)).data.miembros, 3);
  assert.equal((await f.pedir(`/granjas/${granja}/invitaciones`, undefined, vet)).status, 403);
  assert.equal((await f.pedir(`/granjas/${granja}/miembros`, undefined, otro)).status, 403);
  assert.equal((await f.pedir('/logout', {}, dueno)).status, 200);
  assert.equal((await f.pedir('/vinculaciones', undefined, dueno)).status, 401);
});

test('confirmación, recuperación de contraseña y revocación de sesiones', async (t) => {
  const f = await fixture(t);
  const registro = { email: 'ana@ejemplo.com', password: 'secreta1', data: { nombre: 'Ana' } };
  assert.equal((await f.pedir('/auth/registro', registro)).status, 201);
  assert.equal((await f.pedir('/auth/login', registro)).status, 403);
  let enlace = new URL(f.mensajes.at(-1).text.match(/http:\/\/\S+/)[0]);
  const confirmacion = await f.pedir(enlace.pathname + enlace.search);
  assert.equal(confirmacion.status, 302);
  assert.equal(confirmacion.location, 'http://localhost:3000');
  assert.equal((await f.pedir(enlace.pathname + enlace.search)).status, 400);
  const sesion = (await f.pedir('/auth/login', registro)).data.access_token;
  assert.equal((await f.pedir('/auth/login', { ...registro, password: 'incorrecta' })).status, 401);
  assert.equal((await f.pedir('/auth/recuperar', { email: registro.email })).status, 200);
  const enlaceRestablecer = new URL(f.mensajes.at(-1).text.match(/http:\/\/localhost:3000\/\?restablecer=[a-f0-9]{64}/)[0]);
  const tokenRecuperacion = enlaceRestablecer.searchParams.get('restablecer');
  assert.ok(tokenRecuperacion, 'el correo debe abrir la app en la pantalla de restablecimiento');
  const datos = { token: tokenRecuperacion, password: 'nueva-clave' };
  assert.equal((await f.pedir('/auth/restablecer', datos)).status, 200);
  assert.equal((await f.pedir('/auth/restablecer', datos)).status, 400);
  assert.equal((await f.pedir('/vinculaciones', undefined, sesion)).status, 401);
  assert.equal((await f.pedir('/auth/login', registro)).status, 401);
  assert.equal((await f.pedir('/auth/login', { ...registro, password: datos.password })).status, 200);
  assert.equal(f.db.prepare('SELECT password FROM cuentas').get().password.includes(datos.password), false);
});

test('Swagger UI y contrato disponibles sin sesión; no contienen secretos', async (t) => {
  const f = await fixture(t);
  assert.deepEqual(await f.pedir('/health'), { status: 200, data: { ok: true } });
  assert.match((await f.pedir('/docs/')).data, /swagger-ui/);
  const contrato = await f.pedir('/openapi.json');
  assert.equal(contrato.status, 200);
  assert.ok(contrato.data.paths['/dynamic-action']);
  assert.ok(contrato.data.paths['/es_administrador']);
  assert.equal(contrato.data.info.title, 'VetLink API — Node.js + SQLite + Mailgun');
  assert.ok(contrato.data.paths['/health']);
  assert.ok(contrato.data.paths['/invitaciones'].post);
  assert.ok(contrato.data.paths['/auth/restablecer'].post);
  assert.ok(contrato.data.paths['/auth/restablecer'].get);
});

test('SQLite conserva los datos al reiniciar', () => {
  const dir = mkdtempSync(join(tmpdir(), 'vetlink-'));
  const path = join(dir, 'datos.sqlite');
  try {
    let db = abrirBase(path);
    db.prepare('INSERT INTO cuentas(id,email,nombre,password) VALUES(?,?,?,?)').run('id', 'a@ejemplo.com', 'Ana', 'hash');
    db.close();
    db = abrirBase(path);
    assert.equal(db.prepare('SELECT nombre FROM cuentas').get().nombre, 'Ana');
    db.close();
  } finally { rmSync(dir, { recursive: true, force: true }); }
});

test('Mailgun usa la región y credencial del servidor, y expone errores controlados', async () => {
  const env = { MAILGUN_API_KEY: 'prueba', MAILGUN_DOMAIN: 'sandbox.mailgun.org', MAILGUN_FROM: 'VetLink <mail@sandbox.mailgun.org>', MAILGUN_REGION: 'EU' };
  const mensaje = { to: 'test@ejemplo.com', subject: 'Prueba', text: 'Invitación' };
  await mailgun(env, async (url, options) => {
    assert.equal(url, 'https://api.eu.mailgun.net/v3/sandbox.mailgun.org/messages');
    assert.equal(options.body.get('to'), mensaje.to);
    assert.equal(options.headers.Authorization, `Basic ${Buffer.from('api:prueba').toString('base64')}`);
    return new Response('{}');
  })(mensaje);
  await assert.rejects(mailgun(env, async () => new Response(JSON.stringify({ message: 'Activa la cuenta' }), { status: 403 }))(mensaje), { status: 502, message: 'Mailgun rechazó el envío (HTTP 403): Activa la cuenta' });
  await assert.rejects(mailgun(env, async () => { throw new Error('timeout'); })(mensaje), { status: 502 });
  await assert.rejects(mailgun({})(mensaje), { status: 503 });
});
