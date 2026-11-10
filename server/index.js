import { crearApp } from './app.js';
import { abrirBase } from './database.js';
import { mailgun } from './mailgun.js';
import { mkdirSync } from 'node:fs';
import { dirname } from 'node:path';

const publicUrl = process.env.PUBLIC_URL || (process.env.RAILWAY_PUBLIC_DOMAIN ? `https://${process.env.RAILWAY_PUBLIC_DOMAIN}` : undefined);
if (!publicUrl || !/^https?:\/\//.test(publicUrl)) throw new Error('Configura PUBLIC_URL o genera un dominio público en Railway');
const databasePath = process.env.DATABASE_PATH || './vetlink.sqlite';
mkdirSync(dirname(databasePath), { recursive: true });
const db = abrirBase(databasePath);
if (process.env.ADMIN_EMAIL) {
  db.prepare('UPDATE cuentas SET administrador_tecnico = 1 WHERE lower(email) = lower(?)').run(process.env.ADMIN_EMAIL.trim());
}
const app = crearApp({
  db, enviar: mailgun(process.env), publicUrl: publicUrl.replace(/\/$/, ''),
  trustProxy: process.env.TRUST_PROXY === '1' || process.env.RAILWAY_ENVIRONMENT_ID ? 1 : false,
});
const server = app.listen(Number(process.env.PORT || 3000), process.env.HOST || '0.0.0.0', () => {
  console.log(`VetLink API: ${publicUrl} — Swagger UI: ${publicUrl}/docs`);
});
for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, () => server.close(() => { db.close(); process.exit(0); }));
