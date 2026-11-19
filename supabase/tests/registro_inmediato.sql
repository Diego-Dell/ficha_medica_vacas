begin;
insert into auth.users(id,email,raw_user_meta_data) values
('91000000-0000-4000-8000-000000000001','registro-completo@example.invalid','{"nombre":"Dueño de prueba"}');
do $$ begin
  begin
    perform public.registrar_solicitud_con_pdf('91000000-0000-4000-8000-000000000001',
      '91000000-0000-4000-8000-000000000002','Prueba Sprint 1',2,'PDF-PRUEBA',
      '91000000-0000-4000-8000-000000000001/91000000-0000-4000-8000-000000000002/terreno.pdf');
    raise exception 'PRUEBA FALLIDA: se registró sin PDF';
  exception when others then
    if sqlerrm like 'PRUEBA FALLIDA:%' then raise; end if;
  end;
end $$;
insert into storage.objects(bucket_id,name,metadata) values('documentos-granjas',
'91000000-0000-4000-8000-000000000001/91000000-0000-4000-8000-000000000002/terreno.pdf',
'{"mimetype":"application/pdf","size":100}');
select public.registrar_solicitud_con_pdf('91000000-0000-4000-8000-000000000001',
'91000000-0000-4000-8000-000000000002','Prueba Sprint 1',2,'PDF-PRUEBA',
'91000000-0000-4000-8000-000000000001/91000000-0000-4000-8000-000000000002/terreno.pdf');
do $$ begin
  if not exists(select 1 from public.granjas g join public.vinculaciones v on v.granja_id=g.id
    join public.cuentas c on c.id=v.cuenta_id where g.id='91000000-0000-4000-8000-000000000002'
      and not g.confirmada and g.motivo_rechazo is null and v.rol='dueno' and v.activa
      and c.identificador='registro-completo@example.invalid') then
    raise exception 'La solicitud no está en la lista para revisión';
  end if;
  if has_function_privilege('anon','public.registrar_solicitud_con_pdf(uuid,uuid,text,numeric,text,text)','execute')
    or has_function_privilege('authenticated','public.registrar_solicitud_con_pdf(uuid,uuid,text,numeric,text,text)','execute') then
    raise exception 'La operación debe ser exclusiva del servidor';
  end if;
end $$;
select 'Registro inmediato: PDF obligatorio, solicitud y dueño disponibles para revisión; permisos correctos' as resultado;
rollback;
