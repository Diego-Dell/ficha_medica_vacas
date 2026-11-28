-- No deja usuarios, granjas ni objetos: todas las pruebas terminan en rollback.
begin;
do $$
declare
  dueno uuid := gen_random_uuid();
  otro uuid := gen_random_uuid();
  administrador uuid := gen_random_uuid();
  granja uuid;
  segunda uuid;
  ruta text;
  denegado boolean := false;
begin
  insert into auth.users(id,email,raw_user_meta_data) values
    (dueno,dueno::text||'@example.invalid','{"nombre":"Prueba documento"}'),
    (otro,otro::text||'@example.invalid','{"nombre":"Prueba otro"}'),
    (administrador,administrador::text||'@example.invalid','{"nombre":"Prueba admin"}');
  update public.cuentas set administrador_tecnico=true where id=administrador;
  perform set_config('request.jwt.claim.sub',dueno::text,true);
  granja := public.registrar_granja('Documento prueba',10,dueno::text,'pendiente/prueba.pdf');
  segunda := public.registrar_granja('Otra prueba',10,otro::text,'prueba.pdf');
  ruta := dueno::text||'/'||granja::text||'/prueba/terreno.pdf';
  assert public.puede_subir_documento(ruta), 'Dueño puede subir a su granja pendiente';
  assert not public.puede_subir_documento(otro::text||'/'||granja::text||'/falso.pdf');
  execute 'set local role authenticated';
  insert into storage.objects(bucket_id,name) values('documentos-granjas',ruta);
  perform public.adjuntar_documento_granja(granja,ruta);
  execute 'reset role';
  begin
    update public.granjas set documentos_terreno='storage/'||ruta where id=segunda;
  exception when raise_exception then denegado:=true;
  end;
  assert denegado, 'No se puede vincular archivo de otra granja';
  perform set_config('request.jwt.claim.sub',otro::text,true);
  assert not public.puede_subir_documento(ruta);
  denegado:=false;
  begin
    perform public.adjuntar_documento_granja(granja,ruta);
  exception when raise_exception then denegado:=true;
  end;
  assert denegado, 'Otra cuenta no puede adjuntar documentos';
  assert not public.puede_leer_documento(ruta);
  execute 'set local role authenticated';
  assert (select count(*)=0 from storage.objects where bucket_id='documentos-granjas' and name=ruta), 'RLS oculta documento ajeno';
  execute 'reset role';
  insert into public.vinculaciones(cuenta_id,granja_id,rol) values(otro,granja,'veterinario');
  assert not public.puede_leer_documento(ruta), 'Veterinario no consulta documentación del terreno';
  update public.vinculaciones set rol='trabajador' where cuenta_id=otro and granja_id=granja;
  assert not public.puede_leer_documento(ruta), 'Trabajador no consulta documentación del terreno';
  perform set_config('request.jwt.claim.sub',administrador::text,true);
  assert public.puede_leer_documento(ruta), 'Administrador lee documento asociado';
  execute 'set local role authenticated';
  assert (select count(*)=1 from storage.objects where bucket_id='documentos-granjas' and name=ruta);
  execute 'reset role';
  perform public.confirmar_granja(granja);
  perform set_config('request.jwt.claim.sub',dueno::text,true);
  assert not public.puede_subir_documento(ruta), 'No sustituir documentación ya aprobada';
  assert public.puede_leer_documento(ruta);
  update public.cuentas set activa=false where id=dueno;
  assert not public.puede_leer_documento(ruta);
  assert not has_function_privilege('anon','public.puede_leer_documento(text)','execute');
  assert (select not public and file_size_limit=10485760 from storage.buckets where id='documentos-granjas');
end;
$$;
rollback;
select 'Documentos: permisos y validaciones correctos; pruebas revertidas' as resultado;
