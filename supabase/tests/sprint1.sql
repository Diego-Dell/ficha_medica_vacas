-- Ejecutar completo en SQL Editor. Todo usuario y dato de prueba se revierte.
begin;
do $$
declare
  dueno uuid := gen_random_uuid();
  trabajador uuid := gen_random_uuid();
  administrador uuid := gen_random_uuid();
  granja uuid;
  otra uuid;
  pendiente uuid;
  invitacion uuid;
  denegado boolean;
  correo text;
begin
  insert into auth.users(id, email, raw_user_meta_data) values
    (dueno, dueno::text || '@example.invalid', '{"nombre":"Prueba dueño"}'),
    (trabajador, trabajador::text || '@example.invalid', '{"nombre":"Prueba trabajador"}'),
    (administrador, administrador::text || '@example.invalid', '{"nombre":"Prueba administrador"}');
  update public.cuentas set administrador_tecnico = true where id = administrador;
  correo := trabajador::text || '@example.invalid';

  perform set_config('request.jwt.claim.sub', dueno::text, true);
  perform set_config('request.jwt.claims', jsonb_build_object('sub',dueno,'email',dueno::text || '@example.invalid')::text,true);
  granja := public.registrar_granja('Prueba Sprint 1', 10, dueno::text, 'prueba.pdf');
  otra := public.registrar_granja('Prueba otra granja', 10, trabajador::text, 'prueba.pdf');
  pendiente := public.registrar_granja('Prueba revisión', 10, administrador::text, 'prueba.pdf');
  denegado := false;
  begin
    perform public.rechazar_granja(pendiente, 'No autorizado');
  exception when raise_exception then denegado := true;
  end;
  assert denegado, 'El dueño no debe rechazar solicitudes';

  perform set_config('request.jwt.claim.sub', administrador::text, true);
  perform public.confirmar_granja(granja);
  perform public.confirmar_granja(otra);
  perform public.rechazar_granja(pendiente, 'Documento ilegible');
  assert (select not confirmada and motivo_rechazo = 'Documento ilegible' from public.granjas where id = pendiente);
  denegado := false;
  begin
    perform public.confirmar_granja(pendiente);
  exception when check_violation then denegado := true;
  end;
  assert denegado, 'Una revisión vieja no puede aprobar un rechazo';
  denegado := false;
  begin
    perform public.rechazar_granja(granja, 'Ya confirmada');
  exception when raise_exception then denegado := true;
  end;
  assert denegado, 'No se rechaza una granja confirmada';

  insert into public.invitaciones(granja_id, correo, rol)
    values (granja, correo, 'trabajador') returning id into invitacion;
  assert (select count(*) = 0 from public.mis_invitaciones()), 'Solo el correo invitado ve el detalle';
  perform set_config('request.jwt.claim.sub', trabajador::text, true);
  perform set_config('request.jwt.claims', jsonb_build_object('sub',trabajador,'email',correo)::text,true);
  assert (select count(*) = 1 from public.mis_invitaciones() where id = invitacion and granja_nombre = 'Prueba Sprint 1');
  update public.cuentas set activa = false where id = trabajador;
  assert (select count(*) = 0 from public.mis_invitaciones()), 'Una cuenta desactivada no consulta invitaciones';
  update public.cuentas set activa = true where id = trabajador;
  perform public.aceptar_invitacion(invitacion);
  assert (select activa and rol = 'trabajador' from public.vinculaciones where granja_id = granja and cuenta_id = trabajador);
  insert into public.vinculaciones(cuenta_id,granja_id,rol) values(trabajador,otra,'veterinario');
  denegado := false;
  begin
    perform public.expulsar_miembro(granja,dueno);
  exception when raise_exception then denegado := true;
  end;
  assert denegado, 'Un trabajador no puede expulsar';

  perform set_config('request.jwt.claim.sub', dueno::text, true);
  denegado := false;
  begin
    perform public.expulsar_miembro(granja,dueno);
  exception when raise_exception then denegado := true;
  end;
  assert denegado, 'El dueño no se expulsa';
  insert into public.invitaciones(granja_id, correo, rol)
    values (granja, correo, 'trabajador') returning id into invitacion;
  perform public.expulsar_miembro(granja,trabajador);
  assert (select not activa from public.vinculaciones where granja_id = granja and cuenta_id = trabajador);
  assert (select activa from public.vinculaciones where granja_id = otra and cuenta_id = trabajador);
  assert (select activa from public.cuentas where id = trabajador);
  assert (select not vigente from public.invitaciones where id = invitacion);
  perform set_config('request.jwt.claim.sub', trabajador::text, true);
  denegado := false;
  begin
    perform public.aceptar_invitacion(invitacion);
  exception when raise_exception then denegado := true;
  end;
  assert denegado, 'Una invitación anterior no recupera el acceso expulsado';
  assert not has_function_privilege('anon','public.expulsar_miembro(uuid,uuid)','execute');
  assert not has_function_privilege('anon','public.rechazar_granja(uuid,text)','execute');
  assert not has_function_privilege('anon','public.mis_invitaciones()','execute');
end;
$$;
rollback;
select 'Sprint 1: permisos y flujos correctos; datos de prueba revertidos' as resultado;
