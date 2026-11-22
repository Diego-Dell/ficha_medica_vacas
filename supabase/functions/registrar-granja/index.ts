import { createClient } from 'npm:@supabase/supabase-js@2';

const headers = {'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, apikey, content-type, x-client-info','Content-Type':'application/json'};
const responder = (datos: unknown, estado = 200) => new Response(JSON.stringify(datos), {status: estado, headers});
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', {headers});
  if (req.method !== 'POST') return responder({error:'Método no permitido'},405);
  const db = createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false}});
  let creado: string | undefined;
  let ruta: string | undefined;
  let guardado = false;
  let etapa = 'validar';
  try {
    if (Number(req.headers.get('content-length') ?? 0)>11*1024*1024) return responder({error:'PDF demasiado grande'},400);
    const form = await req.formData();
    const texto = (k: string) => String(form.get(k) ?? '').trim();
    const nombre = texto('nombre'), correo = texto('correo').toLowerCase(), granja = texto('granja'), runsa = texto('runsa');
    const clave = String(form.get('contrasena') ?? '');
    const superficie = Number(texto('superficie'));
    const pdf = form.get('pdf');
    if (!nombre || !granja || !runsa || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(correo) || clave.length<6 || !Number.isFinite(superficie) || superficie<=0 || !(pdf instanceof File)) return responder({error:'Completá todos los campos y adjuntá el PDF'},400);
    if (!pdf.name.toLowerCase().endsWith('.pdf') || !pdf.size || pdf.size>10485760 || await pdf.slice(0,5).text()!=='%PDF-') return responder({error:'Adjuntá un PDF válido de hasta 10 MB'},400);
    // No se confirma el correo ni se inicia sesión por cuenta del usuario.
    const cuenta = await db.auth.admin.createUser({email:correo,password:clave,email_confirm:false,user_metadata:{nombre}});
    if (cuenta.error || !cuenta.data.user) return responder({error:cuenta.error?.code==='email_exists' ? 'Ya existe una cuenta con ese correo. Iniciá sesión' : 'No se pudo crear la cuenta; verificá el correo y la contraseña'},400);
    creado = cuenta.data.user.id;
    const id = crypto.randomUUID();
    ruta = `${creado}/${id}/${pdf.name.replace(/[^a-zA-Z0-9._-]/g,'_')}`;
    etapa = 'subir PDF';
    // El selector Android envía el File como octet-stream. Los bytes permiten
    // fijar application/pdf también en el transporte hacia Storage.
    const subida = await db.storage.from('documentos-granjas').upload(ruta,await pdf.arrayBuffer(),{contentType:'application/pdf'});
    if (subida.error) throw subida.error;
    etapa = 'guardar solicitud';
    const registro = await db.rpc('registrar_solicitud_con_pdf',{p_cuenta:creado,p_granja:id,p_nombre:granja,p_hectareas:superficie,p_runsa:runsa,p_ruta:ruta});
    if (registro.error) throw registro.error;
    guardado = true;
    // El correo verifica la cuenta; la solicitud ya está disponible al administrador.
    const envio = await db.auth.resend({type:'signup',email:correo,options:{emailRedirectTo:'vetlink://confirmar'}});
    return responder({id,documento:`storage/${ruta}`,correoEnviado:!envio.error});
  } catch (error) {
    const codigo = String((error as {code?:string;statusCode?:string})?.code ?? (error as {statusCode?:string})?.statusCode ?? 'desconocido');
    console.error('Registro de granja rechazado', {etapa,codigo});
    // Solo se revierte la cuenta recién creada por esta petición fallida.
    if (!guardado && creado) {
      if (ruta) await db.storage.from('documentos-granjas').remove([ruta]);
      await db.auth.admin.deleteUser(creado);
    }
    return responder({error:codigo==='23505' ? 'Ya existe una granja con ese RUNSA' :
      etapa==='subir PDF' ? 'No se pudo subir el PDF. Revisá el archivo e intentá nuevamente' :
      'No se pudo guardar la solicitud. Intentá nuevamente'},400);
  }
});
