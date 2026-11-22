begin;
create function public.registrar_solicitud_con_pdf(p_cuenta uuid,p_granja uuid,p_nombre text,p_hectareas numeric,p_runsa text,p_ruta text)
returns void language plpgsql security definer set search_path='' as $$
begin
  if split_part(p_ruta,'/',1)<>p_cuenta::text or split_part(p_ruta,'/',2)<>p_granja::text
    or not exists(select 1 from public.cuentas where id=p_cuenta and activa)
    or nullif(btrim(p_nombre),'') is null or nullif(btrim(p_runsa),'') is null or p_hectareas<=0 then
    raise exception 'Datos incompletos';
  end if;
  insert into public.granjas(id,nombre,hectareas,runsa,documentos_terreno)
  values(p_granja,btrim(p_nombre),p_hectareas,btrim(p_runsa),'storage/'||p_ruta);
  insert into public.vinculaciones(cuenta_id,granja_id,rol) values(p_cuenta,p_granja,'dueno');
end;
$$;
revoke all on function public.registrar_solicitud_con_pdf(uuid,uuid,text,numeric,text,text) from public,anon,authenticated;
grant execute on function public.registrar_solicitud_con_pdf(uuid,uuid,text,numeric,text,text) to service_role;
notify pgrst,'reload schema';
commit;
