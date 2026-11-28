begin;
select set_config('rf09.admin', (select id::text from public.cuentas where activa and administrador_tecnico limit 1), true);
select set_config('rf09.normal', (select c.id::text from public.cuentas c join public.vinculaciones v on v.cuenta_id=c.id where c.activa and not c.administrador_tecnico and v.activa and v.rol::text='trabajador' limit 1), true);
select set_config('rf09.ficha', (select f.id::text from public.fichas_bovinas f join public.granjas g on g.id=f.granja_id where f.fecha_baja is null and g.confirmada limit 1),true);
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', current_setting('rf09.admin'), 'role','authenticated')::text, true);
do $$
declare antes bigint; despues bigint;
begin
  if not public.es_administrador() then raise exception 'No se recuperó el rol de administrador'; end if;
  perform public.programar_prevencion(current_setting('rf09.ficha')::uuid, 'Control', 'RF09 prueba revertida', current_date);
  select count(*) into antes from public.auditoria_administrador where administrador_id=auth.uid();
  update public.cuentas set nombre=left(coalesce(nombre, 'Cuenta'), 100)||' RF09' where id=auth.uid();
  select count(*) into despues from public.auditoria_administrador where administrador_id=auth.uid();
  if despues <= antes then raise exception 'No se registró la auditoría'; end if;
  insert into public.observaciones_cuidados(ficha_id,registrado_por,fecha_hora,observado,cuidado_realizado) values(current_setting('rf09.ficha')::uuid,auth.uid(),now(),'RF09 prueba revertida','Comprobacion tecnica');
  raise notice 'OK: administrador, indicación veterinaria, cuidados y auditoría';
end;
$$;
select set_config('request.jwt.claims', json_build_object('sub', current_setting('rf09.normal'), 'role','authenticated')::text,true);
do $$
declare bloqueado boolean := false;
begin
  if public.es_administrador() then raise exception 'Un trabajador obtuvo administración'; end if;
  begin
    perform public.programar_prevencion(current_setting('rf09.ficha')::uuid, 'Control', 'RF09 prueba revertida', current_date);
  exception when insufficient_privilege then bloqueado:=true;
  end;
  if not bloqueado then raise exception 'El trabajador obtuvo permiso veterinario'; end if;
  bloqueado:=false;
  begin
    update public.cuentas set administrador_tecnico=true where id=auth.uid();
  exception when insufficient_privilege then bloqueado:=true;
  end;
  if not bloqueado then raise exception 'Se permitió otorgarse administración'; end if;
  raise notice 'OK: trabajador sin permiso administrativo ni clínico';
end;
$$;
rollback;
