# Pruebas con Swagger UI — sin Supabase

Arranca el servidor desde `server` con `npm.cmd start` y abre **http://localhost:3001/docs**. Swagger UI y API usan el mismo origen; no se requiere clave ni referencia de Supabase.

## Preparar cuentas

Sigue el README principal para configurar Mailgun y `ADMIN_EMAIL`. Registra al dueño y confirma el correo. El administrador inicia sesión, consulta `/administracion/granjas-pendientes` y aprueba la granja con `/administracion/granjas/{id}/confirmar`. Registra también una cuenta invitada y otro dueño para comprobar permisos.

En sandbox, todos los correos que recibirán mensajes deben estar confirmados en **Mailgun → Authorized Recipients**. La API no obtiene ni recorre esa lista: utiliza el correo indicado en la invitación.

1. En `/auth/login`, pulsa **Try it out**, introduce correo y contraseña y ejecuta.
2. Copia `access_token` en **Authorize**, sin el prefijo `Bearer`.
3. Obtén el ID de granja en `/vinculaciones`.
4. Guarda una invitación con `/invitaciones` (POST).
5. Copia su `id` en `/dynamic-action` y ejecuta. Repite con el mismo ID para reenviar.

## Casos para presentar

La tabla contiene resultados esperados. Registra tus resultados reales y adjunta evidencias.

| Caso | Acción | Resultado esperado |
| --- | --- | --- |
| Invitación veterinario | Dueño guarda invitación con rol `veterinario` y luego ejecuta `/dynamic-action` | 201 al guardar; 200 al enviar; correo recibido |
| Invitación trabajador | Repetir con otro destinatario y rol `trabajador` | 201 y 200 |
| Reenvío | Ejecutar `/dynamic-action` otra vez con el mismo ID | 200, otro correo, la misma invitación |
| Sin sesión | Logout en Authorize y ejecutar envío | 401 |
| Token inválido | Autorizar texto inventado | 401 |
| Dueño de otra granja | Autorizar su token y usar la invitación anterior | 403 |
| Trabajador/veterinario | Autorizar su token e intentar crear o enviar invitación | 403 |
| Granja en revisión | Intentar invitar antes de aprobar la granja | 403 |
| Rol dueño | Crear invitación con rol `dueno` | 400 |
| Duplicada | Crear otra invitación pendiente para el mismo correo/granja | 409 |
| Fallo Mailgun | Solo en servidor de prueba: colocar clave Mailgun incorrecta en `.env`, reiniciar y enviar | 502; invitación pendiente conservada |
| Recuperación | Restaurar la clave, reiniciar y reenviar con el mismo ID | 200; no crea otra invitación |
| Aceptación | Invitado verificado inicia sesión, lista `/invitaciones` y usa `/aceptar_invitacion` | 200; aparece su granja en `/vinculaciones` |
| Invitación ajena | Otro usuario intenta aceptarla | 403 |
| Ya aceptada | Dueño intenta reenviarla | 409 |

Para evidencias captura **Request body**, **Server response** y el correo recibido. Revisa `/granjas/{id}/invitaciones` para ver pendientes y `/granjas/{id}/miembros` después de aceptar. No incluyas contraseñas, tokens ni el cURL con Authorization en las capturas. Un 200 del envío significa que Mailgun lo aceptó; consulta Mailgun Logs para la entrega.
