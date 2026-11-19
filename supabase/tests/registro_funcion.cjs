// Prueba la función sin crear usuarios ni enviar correos reales.
const { readFileSync } = require('node:fs');
const { stripTypeScriptTypes } = require('node:module');
const assert = require('node:assert/strict');
const source = stripTypeScriptTypes(readFileSync('supabase/functions/registrar-granja/index.ts','utf8').replace(/^import .*\n/,''));
async function probar(fallo) {
  let handler;
  const acciones = [];
  const db = {
    auth: {
      admin: {
        createUser: async () => { acciones.push('cuenta'); return fallo==='duplicada'
          ? {error:{code:'email_exists'},data:{}} : {data:{user:{id:'dueno'}}}; },
        deleteUser: async () => { acciones.push('revertir cuenta'); },
      },
      resend: async () => { acciones.push('correo'); return {}; },
    },
    storage: {from: () => ({
      upload: async (_,pdf,opciones) => { assert.ok(pdf instanceof ArrayBuffer); assert.equal(new TextDecoder().decode(pdf),'%PDF-1.4 prueba'); assert.equal(opciones.contentType,'application/pdf'); acciones.push('pdf'); return {error:fallo==='pdf' ? {} : null}; },
      remove: async () => { acciones.push('revertir pdf'); },
    })},
    rpc: async (nombre,datos) => { assert.equal(nombre,'registrar_solicitud_con_pdf'); assert.equal(datos.p_cuenta,'dueno'); acciones.push('solicitud'); return {error:fallo==='solicitud' ? {} : null}; },
  };
  new Function('Deno','createClient',source)({env:{get:()=> 'prueba'},serve:f=>handler=f},()=>db);
  const form = new FormData();
  for(const [k,v] of Object.entries({nombre:'Dueño',correo:'prueba@example.invalid',contrasena:'prueba123',granja:'Los Pinos',runsa:'TEST',superficie:'2'})) form.set(k,v);
  if(fallo!=='sin pdf') form.set('pdf',new File(['%PDF-1.4 prueba'],'terreno.pdf'));
  const respuesta = await handler(new Request('https://prueba.invalid',{method:'POST',body:form}));
  if(!fallo){ assert.equal(respuesta.status,200); assert.deepEqual(acciones,['cuenta','pdf','solicitud','correo']); }
  else {
    assert.equal(respuesta.status,400);
    if(fallo==='sin pdf') assert.deepEqual(acciones,[]);
    if(fallo==='duplicada') assert.deepEqual(acciones,['cuenta']);
    if(fallo==='pdf') assert.deepEqual(acciones,['cuenta','pdf','revertir pdf','revertir cuenta']);
    if(fallo==='solicitud') assert.deepEqual(acciones,['cuenta','pdf','solicitud','revertir pdf','revertir cuenta']);
  }
}
(async()=>{
  for(const caso of [null,'sin pdf','duplicada','pdf','solicitud']) await probar(caso);
  console.log('5 escenarios del registro verificados; sin datos ni correos reales');
})().catch(e=>{console.error(e);process.exit(1)});
