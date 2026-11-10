export class ApiError extends Error {
  constructor(status, message) { super(message); this.status = status; }
}

export function mailgun(env, pedir = fetch) {
  return async ({ to, subject, text, html }) => {
    const { MAILGUN_API_KEY: key, MAILGUN_DOMAIN: domain, MAILGUN_FROM: from } = env;
    const region = env.MAILGUN_REGION || 'US';
    if (!key || !domain || !from || !['US', 'EU'].includes(region)) {
      throw new ApiError(503, 'El envío de correo no está configurado');
    }
    const form = new FormData();
    for (const [k, v] of Object.entries({ from, to, subject, text })) form.set(k, v);
    if (typeof html === 'string' && html.length > 0) form.set('html', html);
    let response;
    try {
      response = await pedir(`https://${region === 'EU' ? 'api.eu' : 'api'}.mailgun.net/v3/${encodeURIComponent(domain)}/messages`, {
        method: 'POST', body: form,
        headers: { Authorization: `Basic ${Buffer.from(`api:${key}`).toString('base64')}` },
        signal: AbortSignal.timeout(15000),
      });
    } catch {
      throw new ApiError(502, 'No se pudo confirmar el envío con Mailgun. Puedes reintentar');
    }
    if (!response.ok) {
      const detalle = await response.json().catch(() => ({}));
      const mensaje = typeof detalle.message === 'string' ? detalle.message.trim().slice(0, 300) : '';
      throw new ApiError(502, mensaje
        ? `Mailgun rechazó el envío (HTTP ${response.status}): ${mensaje}`
        : `Mailgun rechazó el envío (HTTP ${response.status})`);
    }
  };
}
