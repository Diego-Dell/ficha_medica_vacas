-- Cambios adicionales sobre el esquema existente. No reemplaza las funciones del equipo.
begin;

alter table public.granjas add column if not exists motivo_rechazo text;
alter table public.granjas add constraint granja_revision_coherente
  check (motivo_rechazo is null or
    (not confirmada and length(btrim(motivo_rechazo)) between 1 and 500));
grant select (motivo_rechazo) on public.granjas to authenticated;

create function public.rechazar_granja(p_granja uuid, p_motivo text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.es_administrador() then
    raise exception 'Solo el administrador puede rechazar solicitudes';
  end if;
  if p_motivo is null or length(btrim(p_motivo)) not between 1 and 500 then
    raise exception 'Escribí un motivo de entre 1 y 500 caracteres';
  end if;
  update public.granjas set motivo_rechazo = btrim(p_motivo)
    where id = p_granja and not confirmada and motivo_rechazo is null;
  if not found then
    raise exception 'La solicitud ya fue revisada o no existe';
  end if;
end;
$$;

create function public.expulsar_miembro(p_granja uuid, p_cuenta uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  -- Comprueba la cuenta y su vínculo actual, aunque la pantalla tenga datos viejos.
  perform 1 from public.vinculaciones v
    join public.cuentas c on c.id = v.cuenta_id
    join public.granjas g on g.id = v.granja_id
    where v.granja_id = p_granja and v.cuenta_id = auth.uid()
      and v.rol = 'dueno' and v.activa and c.activa and g.confirmada
    for share of v, c, g;
  if not found or p_cuenta = auth.uid() then
    raise exception 'Solo el dueño puede expulsar a otro miembro';
  end if;

  -- Impide reutilizar una invitación anterior para recuperar el acceso expulsado.
  update public.invitaciones i set vigente = false
    where i.granja_id = p_granja and i.vigente and not i.aceptada
      and lower(i.correo) = (select lower(c.identificador) from public.cuentas c where c.id = p_cuenta);
  update public.vinculaciones set activa = false
    where granja_id = p_granja and cuenta_id = p_cuenta and activa
      and rol in ('veterinario', 'trabajador');
  if not found then
    raise exception 'El miembro ya no está activo o es dueño';
  end if;
end;
$$;

revoke all on function public.rechazar_granja(uuid, text) from public, anon;
revoke all on function public.expulsar_miembro(uuid, uuid) from public, anon;
grant execute on function public.rechazar_granja(uuid, text) to authenticated;
grant execute on function public.expulsar_miembro(uuid, uuid) to authenticated;
notify pgrst, 'reload schema';
commit;
