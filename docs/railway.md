# Publicar VetLink en Railway

El backend se despliega desde `server/` con Docker y Node 24. No requiere subir un commit a GitHub: Railway CLI puede desplegar los archivos locales. `.env`, claves y bases locales están excluidos del archivo de despliegue y de la imagen.

## Autorizar y elegir proyecto

En una terminal interactiva de tu PC:

```powershell
npx.cmd --yes @railway/cli login
npx.cmd --yes @railway/cli link
```

Selecciona el proyecto, entorno y servicio donde publicar esta API. Si aún no existen, crea un proyecto y un **Empty Service** en Railway, por ejemplo `vetlink-api`, antes de vincularlo. El servicio puede generar cargos según tu plan.

## Configuración en Railway

1. Añade un **Volume** al servicio y móntalo en `/data`. Usa **una sola réplica**: esta implementación guarda SQLite en ese volumen.
2. En **Variables** configura:

   | Variable | Valor |
   | --- | --- |
   | `DATABASE_PATH` | `/data/vetlink.sqlite` |
   | `HOST` | `0.0.0.0` |
   | `PORT` | `3001` |
   | `APP_URL` | URL HTTPS pública de la app Flutter |
   | `APP_ORIGINS` | origen web desde el que se ejecuta Flutter |
   | `ADMIN_EMAIL` | correo de la cuenta administradora |
   | `MAILGUN_API_KEY` | Clave privada nueva de Mailgun |
   | `MAILGUN_DOMAIN` | Tu dominio sandbox completo |
   | `MAILGUN_FROM` | `VetLink <postmaster@TU_DOMINIO_SANDBOX>` |
   | `MAILGUN_REGION` | `US` o `EU` |

3. En **Settings → Networking → Public Networking**, pulsa **Generate Domain** y selecciona el puerto configurado para el servidor. Railway proporciona `RAILWAY_PUBLIC_DOMAIN`: la app utiliza automáticamente `https://` + ese dominio para confirmación de correo. Si usas un dominio propio, configura `PUBLIC_URL=https://tu-dominio` sin barra final. No pongas `localhost` en `PUBLIC_URL`.
4. Desde la raíz Flutter, despliega únicamente el backend:

   ```powershell
   npx.cmd --yes @railway/cli up server --path-as-root
   ```

   La CLI usa el proyecto y servicio elegidos en `link`. En un despliegue desde GitHub, configura **Root Directory** como `/server` y la ruta del archivo de configuración como `/server/railway.json`.
5. Verifica `https://TU_DOMINIO/health` (debe devolver `{"ok":true}`) y abre Swagger en `https://TU_DOMINIO/docs`.

## Confirmación desde el teléfono

Registra una cuenta desde Swagger o Flutter y abre el enlace del nuevo correo. El enlace ahora apunta al dominio HTTPS de Railway. Los correos enviados previamente con localhost conservan la URL vieja: usa `/auth/reenviar-confirmacion` para obtener uno nuevo.

En sandbox, los destinatarios deben estar autorizados y confirmados en Mailgun. Esa autorización se realiza con el correo que envía Mailgun y es distinta de la confirmación de cuenta de VetLink.

Para aprobar una granja, usa la shell del contenedor desplegado (Railway SSH) y ejecuta:

```sh
node confirmar-granja.js
node confirmar-granja.js ID_DE_GRANJA
```

Esto usa el volumen remoto. `railway run` ejecuta comandos localmente con variables remotas y no sirve para editar ese volumen.

Finalmente, cambia el archivo local `config.json`:

```json
{ "API_URL": "https://TU_DOMINIO" }
```

Vuelve a ejecutar Flutter con `--dart-define-from-file=config.json`. La base remota comienza vacía; un despliegue no copia automáticamente la base SQLite local.
