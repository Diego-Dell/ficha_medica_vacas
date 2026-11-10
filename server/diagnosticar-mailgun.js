const { MAILGUN_API_KEY: key, MAILGUN_DOMAIN: domain, MAILGUN_FROM: from, MAILGUN_REGION: region = 'US' } = process.env;
if (!key || !domain || !from || !['US', 'EU'].includes(region)) {
  console.log(JSON.stringify({ configuracion: 'incompleta', apiKey: Boolean(key), dominio: Boolean(domain), remitente: Boolean(from), region }));
  process.exitCode = 1;
} else {
  const host = region === 'EU' ? 'api.eu.mailgun.net' : 'api.mailgun.net';
  const remitenteDomain = from.match(/@([^>\s]+)/)?.[1]?.toLowerCase();
  const respuesta = await fetch(`https://${host}/v3/domains/${encodeURIComponent(domain)}`, {
    headers: { Authorization: `Basic ${Buffer.from(`api:${key}`).toString('base64')}` },
    signal: AbortSignal.timeout(15000),
  });
  const datos = await respuesta.json().catch(() => ({}));
  console.log(JSON.stringify({
    autenticacionYAccesoAlDominio: respuesta.status,
    respuestaMailgun: datos.message || null,
    dominioConfigurado: domain,
    remitenteUsaEseDominio: remitenteDomain === domain.toLowerCase(),
    estadoDominio: datos.domain?.state || null,
    tipoDominio: datos.domain?.type || null,
    regionConfigurada: region,
  }, null, 2));
  if (!respuesta.ok || remitenteDomain !== domain.toLowerCase()) process.exitCode = 1;
  const destinatarioPrueba = process.env.MAILGUN_TEST_TO;
  if (destinatarioPrueba) {
    const mensaje = new FormData();
    mensaje.set('from', from);
    mensaje.set('to', destinatarioPrueba);
    mensaje.set('subject', 'Prueba técnica de correo VetLink');
    mensaje.set('text', 'Prueba de configuración de Mailgun para VetLink. No es necesario responder.');
    const envio = await fetch(`https://${host}/v3/${encodeURIComponent(domain)}/messages`, {
      method: 'POST',
      headers: { Authorization: `Basic ${Buffer.from(`api:${key}`).toString('base64')}` },
      body: mensaje,
      signal: AbortSignal.timeout(15000),
    });
    const resultado = await envio.json().catch(() => ({}));
    console.log(JSON.stringify({ pruebaDeEnvio: envio.status, respuestaMailgun: resultado.message || null }, null, 2));
    if (!envio.ok) process.exitCode = 1;
  }
}
