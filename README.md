# VetLink — Flutter + Node.js + SQLite + Mailgun

VetLink usa su propio backend. Registro, login, sesiones, granjas, miembros, invitaciones y datos veterinarios se guardan en SQLite. Mailgun envía confirmaciones, recuperación e invitaciones desde el servidor. La app y Swagger ya no dependen de Supabase.

## Ejecutar en esta PC

Requiere Node.js 22.13 o superior y Flutter instalado.

1. En `server/.env`, configura `MAILGUN_API_KEY`, `MAILGUN_DOMAIN`, `MAILGUN_FROM` y `MAILGUN_REGION` con los datos privados de tu cuenta. No pongas la clave de Mailgun en Flutter, Swagger ni en Git.
2. Para una prueba local deja el backend en el puerto 3001, `PUBLIC_URL=http://localhost:3001` y `APP_URL=http://localhost:3000`. En un teléfono o instalación publicada, ambas URL deben usar un dominio o una IP accesible desde ese dispositivo y, en producción, HTTPS.
3. Opcionalmente asigna `ADMIN_EMAIL=tu-correo` para que esa cuenta tenga permisos de revisión. Si ya existe, el backend la promueve al reiniciar; si se registra después, se le asigna el permiso al crearla.
4. Desde `server` ejecuta:

   ```powershell
   npm.cmd ci
   npm.cmd start
   ```

5. Abre Swagger en **http://localhost:3001/docs** y verifica **GET /health**. Flutter usa `config.json` con:

   ```json
   { "API_URL": "http://localhost:3001" }
   ```

   En Android Emulator usa `http://10.0.2.2:3001`; en teléfono físico usa la IP LAN de la PC. El backend debe permitir el origen de Flutter en `APP_ORIGINS`.
6. Ejecuta desde la raíz del proyecto:

   ```powershell
   flutter pub get
   flutter run -d chrome --dart-define-from-file=config.json --web-port=3000
   ```

## Flujo de prueba

1. En la app registra una granja y confirma el correo que envía Mailgun.
2. La granja nueva queda pendiente de revisión. Inicia sesión con la cuenta administradora configurada en `ADMIN_EMAIL`. La pantalla **Confirmar granjas** carga las solicitudes pendientes del backend; selecciona una para revisar los datos y confirmar el registro. Al confirmar, Mailgun envía al correo del dueño la aprobación y un enlace para iniciar sesión. Swagger conserva las mismas rutas administrativas para consulta y diagnóstico.
3. Inicia sesión como dueño, invita a un correo con `POST /invitaciones` desde la app (o Swagger), y envía con `/dynamic-action`. El trabajador/veterinario crea la cuenta con ese mismo correo, confirma su correo y luego acepta la invitación en la app.
4. **Olvidé mi contraseña** manda un enlace `http://localhost:3000/?restablecer=...`; abre VetLink en la pantalla de contraseña nueva. Al guardar, se invalida el token y se revocan las sesiones anteriores.

El token de confirmación o recuperación vence en una hora y se usa una sola vez. Si el envío de confirmación falla después del registro, vuelve a enviarlo con `POST /auth/reenviar-confirmacion`.

## Mailgun Sandbox y límites

Los dominios Sandbox suelen aceptar solo destinatarios autorizados en Mailgun. Añade ahí los correos de prueba y confirma la autorización antes de probar. El límite de envío depende del estado y plan de tu cuenta/dominio Mailgun; quitar Supabase elimina el límite de correo de Supabase, pero no cambia los límites propios de Mailgun.

## Migrar datos que están en Supabase

El archivo `schema.sql` define tablas, pero no contiene las filas ni contraseñas. El propietario del proyecto (o alguien con permiso de lectura/exportación) debe exportar a JSON las tablas `cuentas`, `granjas`, `vinculaciones`, `invitaciones`, `fichas_bovinas`, `atenciones_clinicas`, `eventos_reproductivos`, `tratamientos`, `prevenciones` y `aplicaciones`. Reúne los arreglos en un archivo con una propiedad por tabla y guárdalo localmente, sin subirlo a Git.

Haz una copia de seguridad de `server/vetlink.sqlite`, detén el backend y ejecuta desde `server`:

```powershell
node importar-export-supabase.js C:\ruta\a\exportacion.json
```

El importador conserva IDs y relaciones y agrega las filas sin sobrescribir registros existentes. Supabase no exporta contraseñas en esas tablas; las cuentas importadas quedan sin confirmar y deben recibir una nueva confirmación. Luego podrán establecer una contraseña con **Olvidé mi contraseña**. Sin una exportación de filas no hay datos remotos que este proyecto pueda copiar por sí solo.

La base SQLite activa está en `server/vetlink.sqlite` y se conserva al reiniciar. `.env`, `config.json` y los archivos SQLite están excluidos de Git.
