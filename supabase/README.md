# Cambios de Sprint 1

Rama local: `ajustes-sprint1`, basada en `develop` (606c7b9).

Las migraciones de esta carpeta se aplicaron al proyecto Supabase
`wytsgtkmzvnoklbqlvpc` durante este trabajo. No volver a ejecutarlas en ese
proyecto: agregan funciones y una restricción que ya existen allí.
En otra base con el esquema original, aplicar 001, 002, 003 y 004 en ese orden.

- `rechazar_granja`: solo administrador, conserva solicitud y motivo.
- `expulsar_miembro`: solo dueño activo de la granja, desactiva el vínculo;
  conserva cuenta, historial y vínculos con otras granjas.
- `mis_invitaciones`: muestra la granja y el rol solo al destinatario activo.

Las pruebas de `tests/sprint1.sql` usan datos sintéticos dentro de una
transacción y terminan con ROLLBACK. Las pruebas Flutter cubren navegación,
validaciones, errores, roles y alineación de encabezados.

## Alcance visual

Los cuatro paneles muestran sus tarjetas. Solo las acciones del Sprint 1
están conectadas. Las tarjetas de módulos futuros no abren pantallas.
El trabajador no muestra Reportes. Registrar otra granja está en el menú
del dueño, veterinario y trabajador, usando la cuenta actual. Confirmar granjas abre la lista de solicitudes del administrador.

El administrador inicia con Cuentas y accesos y Confirmar granjas. Su menú lateral consulta todas las granjas con los permisos existentes de Supabase. Seleccionar una muestra las dos tarjetas de operaciones con su nombre, manteniendo el panel y rol de Administrador; Gestión general quita esa selección. No registra granjas desde ese menú. La selección no agrega vínculos ni cambia roles en la base de datos. Los módulos fuera del Sprint 1 continúan como tarjetas sin pantallas internas.

El enlace de correo `abrir-invitacion` redirige a `vetlink://invitacion`. La app atiende ese enlace también al arrancar: sin sesión abre Crear cuenta; con invitaciones pendientes para la sesión actual muestra Aceptar invitación. Si está abierta otra cuenta, pide cambiarla antes de abrir el registro invitado. No cierra sesiones ni acepta invitaciones automáticamente. Quien ya tenga cuenta vuelve al login e ingresa con el correo destinatario; se conserva la aceptación existente del equipo.

## Limitaciones que quedan por comprobar o completar

- El usuario confirmó el acceso real del veterinario y del trabajador a sus paneles.
  La recuperación con un correo real y la app cerrada requiere la comprobación manual
  final del usuario; las pruebas automáticas no cambian contraseñas reales.

## Registro con PDF (versión vigente, 19/11/2026)

Aplicadas al proyecto: 202611180001, 002, 003, 004; 202611190001_pdf_obligatorio.sql y 202611190002_registro_inmediato.sql. No volver a ejecutarlas allí.

La función registrar-granja recibe los campos y el PDF al pulsar Enviar registro. Crea la cuenta sin confirmar automáticamente el correo, sube el PDF privado y ejecuta registrar_solicitud_con_pdf para guardar la granja y el vínculo juntos. Solo entonces devuelve éxito y aparece Granja en revisión. La solicitud ya está disponible para el administrador; la confirmación del correo no controla la subida. Si falla guardar el PDF o la solicitud, revierte solamente los recursos nuevos de esa petición. Registrar otra granja usa la cuenta actual y sube antes de registrar.

Solo PDF con firma válida de hasta 10 MB. El administrador abre el documento con un enlace de cinco minutos. La clave de servicio solo existe en Supabase; la app usa la clave pública. La función mantiene Verify JWT activo y la app envía la clave pública en Authorization y apikey.

La confirmación del correo sigue siendo necesaria para iniciar sesión. El registro de granja no agrega pantallas. Las granjas históricas conservan sus datos y aprobación; no se simula un PDF para los registros antiguos incompletos.

Si registrar-granja devuelve correoEnviado=false, la solicitud y el PDF se conservan. Granja en revisión muestra el fallo y permite reenviar la confirmación mediante Auth resend, sin repetir el registro. El login también ofrece reenviar cuando la cuenta todavía no confirmó su correo. Se mantienen los límites de envío de Supabase. El enlace de recuperación verificado se conserva hasta registrar el oyente; la navegación se programa después de montar el navegador y se evita abrir dos veces Nueva contraseña por un mismo enlace.

Pruebas: Flutter (registro multipart, validaciones, roles, navegación), tests/registro_funcion.cjs (5 escenarios sin correos ni usuarios reales), tests/registro_inmediato.sql (rechazo sin PDF, solicitud con dueño y permisos; ROLLBACK). La prueba con correos reales queda a cargo del equipo.
