-- Amplía el permiso existente conservando las reglas de veterinario y ficha activa.
begin;
create or replace function public.validar_veterinario_indicacion(p_ficha uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if public.es_administrador() then
    perform 1 from public.fichas_bovinas f
      join public.granjas g on g.id = f.granja_id
      where f.id = p_ficha and f.fecha_baja is null and g.confirmada
      for share of f, g;
  else
    perform 1 from public.fichas_bovinas f
      join public.granjas g on g.id = f.granja_id
      join public.vinculaciones v on v.granja_id = g.id
      join public.cuentas c on c.id = v.cuenta_id
      where f.id = p_ficha and f.fecha_baja is null and g.confirmada
        and v.cuenta_id = auth.uid() and v.rol::text = 'veterinario' and v.activa and c.activa
      for share of f, g, v, c;
  end if;
  if not found then
    raise exception 'Se necesita un veterinario autorizado o administrador activo y una ficha activa en una granja confirmada' using errcode = '42501';
  end if;
end;
$$;
commit;
