-- Permite mostrar la granja antes de aceptar, sin dar acceso a sus demás datos.
begin;
create function public.mis_invitaciones()
returns table (id uuid, correo text, rol text, enviada_en timestamptz, granja_nombre text)
language sql stable security definer set search_path = '' as $$
  select i.id, i.correo, i.rol::text, i.enviada_en, g.nombre
  from public.invitaciones i
  join public.granjas g on g.id = i.granja_id
  where i.vigente and not i.aceptada
    and lower(i.correo) = lower(auth.jwt() ->> 'email')
    and exists (select 1 from public.cuentas c where c.id = auth.uid() and c.activa)
  order by i.enviada_en;
$$;
revoke all on function public.mis_invitaciones() from public, anon;
grant execute on function public.mis_invitaciones() to authenticated;
notify pgrst, 'reload schema';
commit;
