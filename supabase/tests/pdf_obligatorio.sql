-- Ejecutar después de la migración. Todo se revierte.
begin;
insert into auth.users(id,email,raw_user_meta_data) values
('90000000-0000-4000-8000-000000000001','pdf-registro@example.invalid',
'{"nombre":"Prueba PDF","granja":"No debe crearse","runsa":"TEST","superficie":1,"documento":"pendiente/prueba.pdf"}');
do $$ begin
  if exists(select 1 from public.vinculaciones where cuenta_id='90000000-0000-4000-8000-000000000001') then
    raise exception 'Se creó una granja antes de subir el PDF';
  end if;
end $$;
select set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000001',true);
set local role authenticated;
do $$ begin
  begin
    perform public.registrar_granja('Sin PDF',1,'TEST','pendiente/prueba.pdf');
    raise exception 'PRUEBA FALLIDA: aceptó una referencia local';
  exception when others then
    if sqlerrm like 'PRUEBA FALLIDA:%' then raise; end if;
  end;
  begin
    perform public.registrar_granja('Sin archivo',1,'TEST',
      'storage/90000000-0000-4000-8000-000000000001/90000000-0000-4000-8000-000000000002/terreno.pdf');
    raise exception 'PRUEBA FALLIDA: aceptó un archivo inexistente';
  exception when others then
    if sqlerrm like 'PRUEBA FALLIDA:%' then raise; end if;
  end;
end $$;
insert into storage.objects(bucket_id,name,metadata) values('documentos-granjas',
'90000000-0000-4000-8000-000000000001/90000000-0000-4000-8000-000000000002/terreno.pdf',
'{"mimetype":"application/pdf","size":100}');
select public.registrar_granja('Con PDF',1,'PDF-TEST',
'storage/90000000-0000-4000-8000-000000000001/90000000-0000-4000-8000-000000000002/terreno.pdf');
-- Reintentar no duplica el registro.
select public.registrar_granja('Con PDF',1,'PDF-TEST',
'storage/90000000-0000-4000-8000-000000000001/90000000-0000-4000-8000-000000000002/terreno.pdf');
reset role;
do $$ begin
  if (select count(*) from public.vinculaciones where cuenta_id='90000000-0000-4000-8000-000000000001')<>1 then
    raise exception 'El registro no fue único';
  end if;
end $$;
update public.granjas set confirmada=true where id='90000000-0000-4000-8000-000000000002';
update public.granjas set confirmada=false where id='90000000-0000-4000-8000-000000000002';
update storage.objects set metadata='{"mimetype":"image/png","size":100}'
where bucket_id='documentos-granjas' and name like '90000000-0000-4000-8000-000000000001/%';
do $$ begin
  begin
    update public.granjas set confirmada=true where id='90000000-0000-4000-8000-000000000002';
    raise exception 'PRUEBA FALLIDA: aprobó sin PDF válido';
  exception when others then
    if sqlerrm like 'PRUEBA FALLIDA:%' then raise; end if;
  end;
end $$;
select 'PDF obligatorio: registro, aprobación y reintento verificados' as resultado;
rollback;
