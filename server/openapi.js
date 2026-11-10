const str = { type: 'string' };
const uuid = { type: 'string', format: 'uuid' };
const object = (properties, required = Object.keys(properties)) => ({ type: 'object', properties, required });
const error = { description: 'Error de validación o permisos', content: { 'application/json': { schema: object({ error: str }) } } };
const body = (schema) => ({ required: true, content: { 'application/json': { schema } } });
const paths = {};
function ruta(path, method, summary, schema, auth = true, success = 200) {
  paths[path] ??= {};
  paths[path][method] = {
    summary,
    tags: [path.startsWith('/auth') ? 'Cuentas' : path.includes('invitacion') || path.startsWith('/dynamic-action') ? 'Invitaciones' : 'Granjas'],
    security: auth ? [{ SesionUsuario: [] }] : [],
    parameters: [...path.matchAll(/\{(\w+)\}/g)].map(([, name]) => ({ name, in: 'path', required: true, schema: uuid })),
    ...(schema ? { requestBody: body(schema) } : {}),
    responses: { [success]: { description: 'Operación completada' }, 400: error, 401: error, 403: error, 404: error, 409: error, 429: error, 500: error, 502: error },
  };
}
ruta('/health', 'get', 'Comprobar que el servicio está disponible', null, false);
ruta('/auth/registro', 'post', 'Crear cuenta y enviar confirmación por Mailgun', object({ email: { type: 'string', format: 'email' }, password: { type: 'string', format: 'password', minLength: 6 }, data: object({ nombre: str, granja: str, superficie: { type: 'number' }, runsa: str, documento: str }, ['nombre']) }), false, 201);
paths['/auth/registro'].post.description = 'Cuenta y datos se guardan en SQLite. Para registrar una granja incluye los campos opcionales de granja. Confirma el correo antes de iniciar sesión.';
ruta('/auth/login', 'post', 'Iniciar sesión y obtener access_token', object({ email: { type: 'string', format: 'email' }, password: { type: 'string', format: 'password' } }), false);
paths['/auth/login'].post.responses[200] = { description: 'Token local. Vence en 24 horas.', content: { 'application/json': { schema: object({ access_token: str, user: object({ id: uuid, email: str, nombre: str }) }) } } };
for (const path of ['recuperar', 'reenviar-confirmacion']) ruta(`/auth/${path}`, 'post', path === 'recuperar' ? 'Enviar enlace de recuperación por Mailgun' : 'Reenviar confirmación por Mailgun', object({ email: { type: 'string', format: 'email' } }), false);
ruta('/auth/confirmar', 'get', 'Confirmar correo desde el enlace de Mailgun', null, false);
ruta('/auth/confirmar', 'post', 'Confirmar correo con token', object({ token: str }), false);
ruta('/auth/restablecer', 'get', 'Validar el enlace y abrir la pantalla de restablecimiento', null, false);
ruta('/auth/restablecer', 'post', 'Cambiar contraseña con token de Mailgun', object({ token: str, password: { type: 'string', format: 'password', minLength: 6 } }), false);
ruta('/logout', 'post', 'Cerrar la sesión actual');
ruta('/es_administrador', 'get', 'Consultar si la cuenta tiene permisos administrativos');
ruta('/administracion/granjas-pendientes', 'get', 'Listar granjas que esperan revisión por administrador');
ruta('/administracion/granjas/{id}/confirmar', 'post', 'Aprobar una granja pendiente (solo administrador)');
paths['/administracion/granjas-pendientes'].get.description = 'Devuelve solo solicitudes reales pendientes, junto con el nombre y correo del dueño, RUNSA, superficie y nombre del documento informado.';
paths['/administracion/granjas/{id}/confirmar'].post.description = 'Envía al correo registrado del dueño la confirmación y un enlace de inicio de sesión. La solicitud pasa a confirmada solo si Mailgun acepta el envío.';
ruta('/vinculaciones', 'get', 'Listar mis granjas y roles');
ruta('/registrar_granja', 'post', 'Registrar otra granja con el usuario autenticado como dueño', object({ p_nombre: str, p_hectareas: { type: 'number', minimum: 0, exclusiveMinimum: true }, p_runsa: str, p_documentos: str }), true, 201);
for (const parte of ['miembros', 'invitaciones', 'resumen', 'fichas_bovinas']) ruta(`/granjas/{id}/${parte}`, 'get', `Consultar ${parte} de una granja`);
ruta('/invitaciones', 'get', 'Listar invitaciones dirigidas a mi correo confirmado');
ruta('/invitaciones', 'post', 'Crear invitación pendiente para veterinario o trabajador', object({ granja_id: uuid, correo: { type: 'string', format: 'email' }, rol: { type: 'string', enum: ['veterinario', 'trabajador'] } }), true, 201);
paths['/invitaciones'].post.responses[201] = { description: 'Usa el id en /dynamic-action', content: { 'application/json': { schema: object({ id: uuid }) } } };
ruta('/dynamic-action', 'post', 'Enviar o reenviar invitación por Mailgun', object({ invitacion_id: uuid }));
paths['/dynamic-action'].post.description = 'Mailgun envía el correo usando configuración privada del servidor. La invitación se conserva si el envío falla.';
ruta('/aceptar_invitacion', 'post', 'Aceptar invitación dirigida al correo de la cuenta', object({ p_invitacion: uuid }));
ruta('/granjas/{id}/fichas_bovinas/{animal}/baja', 'post', 'Registrar baja de animal (solo dueño)', object({ fecha_baja: { type: 'string', format: 'date' }, motivo_baja: str }));
export const spec = {
  openapi: '3.0.3',
  info: { title: 'VetLink API — Node.js + SQLite + Mailgun', version: '3.0.0', description: 'Backend propio. Cuentas, sesiones y datos se almacenan en SQLite; confirmaciones, recuperación e invitaciones se envían por Mailgun. No requiere Supabase.' },
  servers: [{ url: '/' }], paths,
  components: { securitySchemes: { SesionUsuario: { type: 'http', scheme: 'bearer', description: 'Pega el access_token devuelto por /auth/login. Nunca pegues aquí la clave de Mailgun.' } } },
};
