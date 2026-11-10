import express from 'express';
import { rateLimit } from 'express-rate-limit';
import swaggerUi from 'swagger-ui-express';
import { randomBytes, randomUUID, scrypt as scryptCallback, timingSafeEqual, createHash } from 'node:crypto';
import { promisify } from 'node:util';
import { ApiError } from './mailgun.js';
import { spec } from './openapi.js';

const scrypt = promisify(scryptCallback);
const hash = (v) => createHash('sha256').update(v).digest('hex');
const token = () => randomBytes(32).toString('hex');
const exigir = (condicion, status, mensaje) => { if (!condicion) throw new ApiError(status, mensaje); };
const escaparHtml = (valor) => String(valor).replace(/[&<>\"']/g, (caracter) => ({
  '&': '&amp;', '<': '&lt;', '>': '&gt;', '\"': '&quot;', "'": '&#39;',
}[caracter]));
const email = (v) => {
  exigir(typeof v === 'string' && /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(v.trim()), 400, 'Correo no válido');
  return v.trim().toLowerCase();
};
const texto = (v) => typeof v === 'string' && v.trim().length > 0 && v.length <= 500;
async function passwordHash(password) {
  exigir(typeof password === 'string' && password.length >= 6 && password.length <= 200, 400, 'Mínimo 6 caracteres y máximo 200');
  const salt = token();
  return `${salt}:${(await scrypt(password, salt, 64)).toString('hex')}`;
}
async function passwordValida(password, almacenada) {
  if (typeof password !== 'string' || password.length > 200) return false;
  const [salt, digest] = almacenada.split(':');
  return timingSafeEqual(await scrypt(password, salt, 64), Buffer.from(digest, 'hex'));
}

export function crearApp({ db, enviar, publicUrl, trustProxy = false }) {
  const app = express();
  app.set('trust proxy', trustProxy);
  const one = (sql, ...args) => db.prepare(sql).get(...args);
  const all = (sql, ...args) => db.prepare(sql).all(...args);
  const run = (sql, ...args) => db.prepare(sql).run(...args);
  const transaccion = (accion) => {
    db.exec('BEGIN IMMEDIATE');
    try { const resultado = accion(); db.exec('COMMIT'); return resultado; }
    catch (e) { db.exec('ROLLBACK'); throw e; }
  };
  app.disable('x-powered-by');
  app.use(express.json({ limit: '16kb' }));
  app.use(express.urlencoded({ extended: false, limit: '16kb' }));
  const origins = new Set((process.env.APP_ORIGINS || 'http://localhost:3000').split(',').map((v) => v.trim()));
  app.use((req, res, next) => {
    const origin = req.headers.origin;
    if (origin && origins.has(origin)) {
      res.set('Access-Control-Allow-Origin', origin);
      res.set('Vary', 'Origin');
      res.set('Access-Control-Allow-Headers', 'Authorization, Content-Type');
      res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    }
    if (req.method === 'OPTIONS') return res.sendStatus(204);
    next();
  });
  app.use((req, res, next) => {
    res.set('Cache-Control', 'no-store');
    res.set('Referrer-Policy', 'no-referrer');
    next();
  });
  app.get('/openapi.json', (_req, res) => res.json(spec));
  app.get('/health', (_req, res) => {
    one('SELECT 1');
    res.json({ ok: true });
  });
  app.use('/docs', swaggerUi.serve, swaggerUi.setup(spec, { swaggerOptions: { persistAuthorization: false } }));
  const limiteAuth = rateLimit({ windowMs: 15 * 60 * 1000, limit: 30, message: { error: 'Demasiados intentos. Intenta más tarde' } });
  app.use('/auth', limiteAuth);

  function nuevaGranja(cuentaId, datos) {
    exigir(texto(datos.p_nombre) && Number.isFinite(datos.p_hectareas) && datos.p_hectareas > 0 && texto(datos.p_runsa), 400, 'Datos de granja no válidos');
    const id = randomUUID();
    run('INSERT INTO granjas(id,nombre,hectareas,runsa,documentos_terreno) VALUES(?,?,?,?,?)',
      id, datos.p_nombre.trim(), datos.p_hectareas, datos.p_runsa.trim(), String(datos.p_documentos || ''));
    run('INSERT INTO vinculaciones(id,granja_id,cuenta_id,rol) VALUES(?,?,?,?)', randomUUID(), id, cuentaId, 'dueno');
    return id;
  }
  async function enlace(cuenta, tipo) {
    const secreto = token();
    run('INSERT INTO enlaces VALUES(?,?,?,?)', hash(secreto), cuenta.id, tipo, Date.now() + 3600000);
    const url = tipo === 'confirmar'
      ? `${publicUrl}/auth/confirmar?token=${secreto}`
      : `${publicUrl}/auth/restablecer?token=${secreto}`;
    const confirmar = tipo === 'confirmar';
    const accion = confirmar ? 'confirmar tu correo' : 'restablecer tu contraseña';
    const etiqueta = confirmar ? 'Confirmar correo' : 'Restablecer contraseña';
    const urlHtml = escaparHtml(url);
    try {
      await enviar({
        to: cuenta.email,
        subject: confirmar ? 'Confirma tu correo en VetLink' : 'Recuperar acceso a VetLink',
        text: `Abre este enlace para ${accion}:\n${url}\n\nSi no puedes abrirlo, copia y pega la dirección completa en tu navegador.\n\nEl enlace vence en una hora.`,
        html: `<!doctype html><html lang="es"><body style="margin:0;padding:32px;background:#f5f6ef;font-family:Arial,sans-serif;color:#294536"><main style="max-width:560px;margin:auto;padding:28px;background:#fff;border:1px solid #dce2d6;border-radius:12px"><h1 style="font-size:24px">${etiqueta}</h1><p>Recibimos una solicitud para ${accion} en VetLink.</p><p><a href="${urlHtml}" style="display:inline-block;padding:13px 22px;background:#2f624b;color:#fff;text-decoration:none;border-radius:8px;font-weight:bold">${etiqueta}</a></p><p>Si el botón no abre la página, copia y pega este enlace completo en tu navegador:</p><p style="overflow-wrap:anywhere;word-break:break-word"><a href="${urlHtml}" style="color:#1155cc;text-decoration:underline">${urlHtml}</a></p><p>El enlace vence en una hora. Si no solicitaste esta acción, puedes ignorar este correo.</p></main></body></html>`,
      });
    } catch (e) {
      run('DELETE FROM enlaces WHERE token = ?', hash(secreto));
      throw e;
    }
  }
  app.post('/auth/registro', async (req, res) => {
    const correo = email(req.body.email);
    const datos = req.body.data;
    exigir(datos && texto(datos.nombre), 400, 'Nombre obligatorio');
    exigir(!one('SELECT id FROM cuentas WHERE email = ?', correo), 409, 'Ya existe una cuenta con ese correo');
    const password = await passwordHash(req.body.password);
    const cuenta = { id: randomUUID(), email: correo };
    transaccion(() => {
      const admin = process.env.ADMIN_EMAIL?.trim().toLowerCase() === correo ? 1 : 0;
      run('INSERT INTO cuentas(id,email,nombre,password,administrador_tecnico) VALUES(?,?,?,?,?)', cuenta.id, correo, datos.nombre.trim(), password, admin);
      if (datos.granja) nuevaGranja(cuenta.id, { p_nombre: datos.granja, p_hectareas: datos.superficie, p_runsa: datos.runsa, p_documentos: datos.documento });
    });
    try { await enlace(cuenta, 'confirmar'); }
    catch (e) { throw new ApiError(e.status || 502, `Cuenta guardada. ${e.message}. Reenvía la confirmación desde Swagger /auth/reenviar-confirmacion`); }
    res.status(201).json({ mensaje: 'Confirma tu correo e inicia sesión' });
  });
  app.post('/auth/reenviar-confirmacion', async (req, res) => {
    const cuenta = one('SELECT * FROM cuentas WHERE email = ?', email(req.body.email));
    if (cuenta && !cuenta.verificada) await enlace(cuenta, 'confirmar');
    res.json({ mensaje: 'Si la cuenta existe y está pendiente, se envió la confirmación' });
  });
  function confirmarCorreo(secreto) {
    const key = hash(String(secreto || ''));
    const fila = one('SELECT * FROM enlaces WHERE token = ? AND tipo = ? AND vence > ?', key, 'confirmar', Date.now());
    exigir(fila, 400, 'Enlace inválido o vencido');
    transaccion(() => {
      run('UPDATE cuentas SET verificada = 1 WHERE id = ?', fila.cuenta_id);
      run('DELETE FROM enlaces WHERE cuenta_id = ? AND tipo = ?', fila.cuenta_id, 'confirmar');
    });
  }
  app.get('/auth/confirmar', (req, res, next) => {
    try {
      confirmarCorreo(req.query.token);
      const appUrl = (process.env.APP_URL || 'http://localhost:3000').replace(/\/$/, '');
      res.redirect(302, appUrl);
    } catch (error) { next(error); }
  });
  app.post('/auth/confirmar', (req, res, next) => {
    try { confirmarCorreo(req.body.token); res.json({ mensaje: 'Correo confirmado' }); }
    catch (error) { next(error); }
  });
  app.post('/auth/login', async (req, res) => {
    const cuenta = one('SELECT * FROM cuentas WHERE email = ?', email(req.body.email));
    exigir(cuenta && cuenta.activa && await passwordValida(req.body.password, cuenta.password), 401, 'Correo o contraseña incorrectos');
    exigir(cuenta.verificada, 403, 'Falta confirmar el correo');
    const secreto = token();
    run('DELETE FROM sesiones WHERE vence <= ?', Date.now());
    run('INSERT INTO sesiones VALUES(?,?,?)', hash(secreto), cuenta.id, Date.now() + 86400000);
    res.json({ access_token: secreto, user: { id: cuenta.id, email: cuenta.email, nombre: cuenta.nombre } });
  });
  app.post('/auth/recuperar', async (req, res) => {
    const cuenta = one('SELECT * FROM cuentas WHERE email = ?', email(req.body.email));
    if (cuenta) await enlace(cuenta, 'restablecer');
    res.json({ mensaje: 'Si el correo tiene una cuenta, te enviamos el enlace' });
  });
  app.get('/auth/restablecer', (req, res) => {
    const secreto = String(req.query.token || '');
    exigir(/^[a-f0-9]{64}$/.test(secreto), 400, 'Enlace no válido');
    const enlaceActivo = one(
      'SELECT token FROM enlaces WHERE token = ? AND tipo = ? AND vence > ?',
      hash(secreto), 'restablecer', Date.now(),
    );
    exigir(enlaceActivo, 400, 'Enlace inválido o vencido');
    const destino = new URL(process.env.APP_URL || 'http://localhost:3000');
    destino.searchParams.set('restablecer', secreto);
    res.redirect(302, destino.toString());
  });
  app.post('/auth/restablecer', async (req, res) => {
    const key = hash(String(req.body.token || ''));
    const password = await passwordHash(req.body.password);
    transaccion(() => {
      const fila = one('SELECT * FROM enlaces WHERE token = ? AND tipo = ? AND vence > ?', key, 'restablecer', Date.now());
      exigir(fila, 400, 'Enlace inválido o vencido');
      run('UPDATE cuentas SET password = ? WHERE id = ?', password, fila.cuenta_id);
      run('DELETE FROM enlaces WHERE cuenta_id = ? AND tipo = ?', fila.cuenta_id, 'restablecer');
      run('DELETE FROM sesiones WHERE cuenta_id = ?', fila.cuenta_id);
    });
    res.json({ mensaje: 'Contraseña actualizada. Inicia sesión en VetLink' });
  });

  app.use((req, _res, next) => {
    const bearer = req.headers.authorization?.match(/^Bearer (\S+)$/i)?.[1];
    const cuenta = bearer && one('SELECT c.* FROM sesiones s JOIN cuentas c ON c.id=s.cuenta_id WHERE s.token=? AND s.vence>?', hash(bearer), Date.now());
    exigir(cuenta, 401, 'Inicia sesión para continuar');
    req.cuenta = cuenta;
    next();
  });
  app.get('/es_administrador', (req, res) => res.json({ administrador: Boolean(req.cuenta.administrador_tecnico) }));
  app.get('/administracion/granjas-pendientes', (req, res) => {
    exigir(req.cuenta.administrador_tecnico, 403, 'Solo un administrador técnico puede revisar granjas');
    const solicitudes = all(`
      SELECT g.*, c.nombre AS dueno, c.email AS correo_dueno
      FROM granjas g
      JOIN vinculaciones v ON v.granja_id=g.id AND v.rol='dueno' AND v.activa=1
      JOIN cuentas c ON c.id=v.cuenta_id
      WHERE g.confirmada=0
      ORDER BY g.nombre COLLATE NOCASE
    `);
    res.json(solicitudes.map((granja) => ({
      ...granja,
      confirmada: Boolean(granja.confirmada),
    })));
  });
  app.post('/administracion/granjas/:id/confirmar', async (req, res) => {
    exigir(req.cuenta.administrador_tecnico, 403, 'Solo un administrador técnico puede confirmar granjas');
    const granja = one(`
      SELECT g.id, g.nombre, c.nombre AS dueno, c.email AS correo_dueno
      FROM granjas g
      JOIN vinculaciones v ON v.granja_id=g.id AND v.rol='dueno' AND v.activa=1
      JOIN cuentas c ON c.id=v.cuenta_id
      WHERE g.id=? AND g.confirmada=0
    `, req.params.id);
    exigir(granja, 404, 'Granja pendiente no encontrada');

    const loginUrl = (process.env.APP_URL || 'http://localhost:3000').replace(/\/$/, '');
    const granjaHtml = escaparHtml(granja.nombre);
    const duenoHtml = escaparHtml(granja.dueno);
    const loginUrlHtml = escaparHtml(loginUrl);
    await enviar({
      to: granja.correo_dueno,
      subject: `La granja ${granja.nombre} fue confirmada en VetLink`,
      text: `Hola ${granja.dueno}, la documentación de tu granja ${granja.nombre} está en orden y su registro fue confirmado. Ya puedes iniciar sesión en VetLink: ${loginUrl}`,
      html: `<!doctype html><html lang="es"><body style="margin:0;padding:32px;background:#f5f6ef;font-family:Arial,sans-serif;color:#294536"><main style="max-width:560px;margin:auto;padding:28px;background:#fff;border:1px solid #dce2d6;border-radius:12px"><h1 style="font-size:24px">Granja confirmada</h1><p>Hola ${duenoHtml},</p><p>La documentación de <strong>${granjaHtml}</strong> está en orden y el registro de tu granja fue confirmado.</p><p>Ya puedes ingresar a tu cuenta y empezar a usar VetLink.</p><p><a href="${loginUrlHtml}" style="display:inline-block;padding:13px 22px;background:#2f624b;color:#fff;text-decoration:none;border-radius:8px;font-weight:bold">Iniciar sesión</a></p></main></body></html>`,
    });

    const result = run('UPDATE granjas SET confirmada=1 WHERE id=? AND confirmada=0', req.params.id);
    exigir(result.changes, 409, 'La solicitud cambió mientras se confirmaba');
    res.json({ ok: true, correoEnviado: true });
  });
  function miembro(req, granjaId, dueno = false) {
    const vinculo = one('SELECT * FROM vinculaciones WHERE cuenta_id=? AND granja_id=? AND activa=1', req.cuenta.id, granjaId);
    exigir(vinculo && (!dueno || vinculo.rol === 'dueno'), 403, dueno ? 'Solo el dueño de esta granja puede realizar esta acción' : 'No perteneces a esta granja');
    exigir(one('SELECT confirmada FROM granjas WHERE id=?', granjaId)?.confirmada, 403, 'La granja todavía está en revisión');
  }
  app.post('/logout', (req, res) => {
    run('DELETE FROM sesiones WHERE token=?', hash(req.headers.authorization.split(' ')[1]));
    res.json({ ok: true });
  });
  app.get('/vinculaciones', (req, res) => res.json(all('SELECT v.rol,g.* FROM vinculaciones v JOIN granjas g ON g.id=v.granja_id WHERE v.cuenta_id=? AND v.activa=1', req.cuenta.id)
    .map(({ rol, ...g }) => ({ rol, granjas: { ...g, confirmada: Boolean(g.confirmada) } }))));
  app.post('/registrar_granja', (req, res) => res.status(201).json({ id: transaccion(() => nuevaGranja(req.cuenta.id, req.body)) }));
  const pendientes = (id) => all('SELECT * FROM invitaciones WHERE granja_id=? AND vigente=1 AND aceptada=0 ORDER BY enviada_en', id);
  app.get('/granjas/:id/miembros', (req, res) => {
    miembro(req, req.params.id);
    res.json(all('SELECT v.rol,c.nombre,c.email FROM vinculaciones v JOIN cuentas c ON c.id=v.cuenta_id WHERE v.granja_id=? AND v.activa=1', req.params.id)
      .map(({ rol, nombre, email }) => ({ rol, cuentas: { nombre, identificador: email } })));
  });
  app.get('/granjas/:id/invitaciones', (req, res) => { miembro(req, req.params.id, true); res.json(pendientes(req.params.id)); });
  app.get('/invitaciones', (req, res) => res.json(all('SELECT * FROM invitaciones WHERE correo=? AND vigente=1 AND aceptada=0', req.cuenta.email)));
  app.post('/invitaciones', (req, res) => {
    const { granja_id: granja, rol } = req.body;
    exigir(typeof granja === 'string', 400, 'Granja obligatoria');
    miembro(req, granja, true);
    const correo = email(req.body.correo);
    exigir(['veterinario', 'trabajador'].includes(rol), 400, 'Solo se puede invitar a veterinarios o trabajadores');
    exigir(!one('SELECT v.id FROM vinculaciones v JOIN cuentas c ON c.id=v.cuenta_id WHERE v.granja_id=? AND c.email=? AND v.activa=1', granja, correo), 409, 'Esa persona ya es miembro de la granja');
    exigir(!one('SELECT id FROM invitaciones WHERE granja_id=? AND correo=? AND vigente=1 AND aceptada=0', granja, correo), 409, 'Esa persona ya tiene una invitación pendiente');
    const id = randomUUID();
    run('INSERT INTO invitaciones(id,granja_id,correo,rol,enviada_en) VALUES(?,?,?,?,?)', id, granja, correo, rol, new Date().toISOString());
    res.status(201).json({ id });
  });
  const limiteCorreo = rateLimit({ windowMs: 60000, limit: 20, keyGenerator: (req) => req.cuenta.id, message: { error: 'Demasiados envíos. Espera un minuto' } });
  app.post('/dynamic-action', limiteCorreo, async (req, res) => {
    exigir(typeof req.body.invitacion_id === 'string', 400, 'Invitación obligatoria');
    const invitacion = one('SELECT i.*,g.nombre FROM invitaciones i JOIN granjas g ON g.id=i.granja_id WHERE i.id=?', req.body.invitacion_id);
    exigir(invitacion, 404, 'Invitación no disponible');
    miembro(req, invitacion.granja_id, true);
    exigir(invitacion.vigente && !invitacion.aceptada, 409, 'La invitación ya no está pendiente');
    await enviar({ to: invitacion.correo, subject: 'Invitación a una granja en VetLink',
      text: `Te invitaron a la granja ${invitacion.nombre} como ${invitacion.rol}.\nAbre VetLink con el correo ${invitacion.correo}. Si aún no tienes cuenta, pulsa “Me invitaron: crear cuenta”, confirma tu correo e inicia sesión. Después podrás aceptar la invitación.`,
      html: `<!doctype html><html lang="es"><body style="margin:0;padding:32px;background:#f5f6ef;font-family:Arial,sans-serif;color:#294536"><main style="max-width:560px;margin:auto;padding:28px;background:#fff;border:1px solid #dce2d6;border-radius:12px"><h1 style="font-size:24px">Te invitaron a VetLink</h1><p>Te invitaron a la granja <strong>${escaparHtml(invitacion.nombre)}</strong> como ${escaparHtml(invitacion.rol)}.</p><p>Abre VetLink con el correo <strong>${escaparHtml(invitacion.correo)}</strong>. Si todavía no tienes cuenta, regístrate, confirma tu correo e inicia sesión. Luego podrás aceptar la invitación.</p><p><a href="${escaparHtml((process.env.APP_URL || 'http://localhost:3000').replace(/\/$/, '') + '/') }" style="display:inline-block;padding:13px 22px;background:#2f624b;color:#fff;text-decoration:none;border-radius:8px;font-weight:bold">Abrir VetLink</a></p></main></body></html>` });
    res.json({ enviado: true });
  });
  app.post('/aceptar_invitacion', (req, res) => {
    exigir(typeof req.body.p_invitacion === 'string', 400, 'Invitación obligatoria');
    transaccion(() => {
      const i = one('SELECT * FROM invitaciones WHERE id=?', req.body.p_invitacion);
      exigir(i && i.correo === req.cuenta.email, 403, 'Esta invitación no está dirigida a tu cuenta');
      exigir(i.vigente && !i.aceptada, 409, 'La invitación ya no está pendiente');
      exigir(!one('SELECT id FROM vinculaciones WHERE granja_id=? AND cuenta_id=? AND activa=1', i.granja_id, req.cuenta.id), 409, 'Ya perteneces a la granja');
      run('INSERT INTO vinculaciones(id,granja_id,cuenta_id,rol) VALUES(?,?,?,?) ON CONFLICT(granja_id,cuenta_id) DO UPDATE SET activa=1,rol=excluded.rol', randomUUID(), i.granja_id, req.cuenta.id, i.rol);
      run('UPDATE invitaciones SET aceptada=1 WHERE id=?', i.id);
    });
    res.json({ ok: true });
  });
  app.get('/granjas/:id/fichas_bovinas', (req, res) => {
    miembro(req, req.params.id);
    res.json(all('SELECT * FROM fichas_bovinas WHERE granja_id=? AND fecha_baja IS NULL ORDER BY identificacion', req.params.id));
  });
  app.post('/granjas/:id/fichas_bovinas/:animal/baja', (req, res) => {
    miembro(req, req.params.id, true);
    exigir(/^\d{4}-\d{2}-\d{2}$/.test(req.body.fecha_baja) && texto(req.body.motivo_baja), 400, 'Fecha y motivo obligatorios');
    const result = run('UPDATE fichas_bovinas SET fecha_baja=?,motivo_baja=? WHERE id=? AND granja_id=? AND fecha_baja IS NULL', req.body.fecha_baja, req.body.motivo_baja.trim(), req.params.animal, req.params.id);
    exigir(result.changes, 404, 'Animal activo no encontrado');
    res.json({ ok: true });
  });
  app.get('/granjas/:id/resumen', (req, res) => {
    const id = req.params.id;
    miembro(req, id);
    const contar = (sql, ...args) => one(sql, ...args).n;
    res.json({
      animales: contar('SELECT COUNT(*) n FROM fichas_bovinas WHERE granja_id=? AND fecha_baja IS NULL', id),
      avisos: contar("SELECT COUNT(*) n FROM prevenciones p JOIN fichas_bovinas a ON a.id=COALESCE(p.ficha_id,p.animal_id) WHERE a.granja_id=? AND a.fecha_baja IS NULL AND p.estado='pendiente' AND p.fecha_programada<=?", id, new Date(Date.now() + 7 * 86400000).toISOString().slice(0, 10)),
      miembros: contar('SELECT COUNT(*) n FROM vinculaciones WHERE granja_id=? AND activa=1', id) + pendientes(id).length,
    });
  });
  app.use((_req, res) => res.status(404).json({ error: 'Ruta no encontrada' }));
  app.use((error, _req, res, _next) => {
    const status = error instanceof ApiError ? error.status : error.type === 'entity.parse.failed' ? 400 : 500;
    res.status(status).json({ error: error instanceof ApiError ? error.message : status === 400 ? 'JSON no válido' : 'No se pudo completar la solicitud' });
  });
  return app;
}
