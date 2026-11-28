-- Documentos privados: solo el dueño de la granja sube; dueño y administrador leen.
begin;
insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('documentos-granjas','documentos-granjas',false,10485760,
  array['application/pdf','image/jpeg','image/png']);

create function public.puede_subir_documento(p_ruta text)
returns boolean language sql stable security definer set search_path = '' as $$
  select split_part(p_ruta,'/',1) = auth.uid()::text and exists (
    select 1 from public.vinculaciones v
    join public.cuentas c on c.id=v.cuenta_id
    join public.granjas g on g.id=v.granja_id
    where v.cuenta_id=auth.uid() and v.activa and c.activa and v.rol='dueno'
      and g.id::text=split_part(p_ruta,'/',2)
      and not g.confirmada and g.motivo_rechazo is null
  );
$$;
create function public.puede_leer_documento(p_ruta text)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.granjas g
    where g.id::text=split_part(p_ruta,'/',2) and (
      (public.es_administrador() and g.documentos_terreno='storage/'||p_ruta)
      or exists (select 1 from public.vinculaciones v join public.cuentas c on c.id=v.cuenta_id
        where v.granja_id=g.id and v.cuenta_id=auth.uid() and v.rol='dueno'
          and v.activa and c.activa and split_part(p_ruta,'/',1)=auth.uid()::text)
    )
  );
$$;
revoke all on function public.puede_subir_documento(text), public.puede_leer_documento(text) from public,anon;
grant execute on function public.puede_subir_documento(text), public.puede_leer_documento(text) to authenticated;

create policy documentos_insertar on storage.objects for insert to authenticated
  with check (bucket_id='documentos-granjas' and public.puede_subir_documento(name));
create policy documentos_actualizar on storage.objects for update to authenticated
  using (bucket_id='documentos-granjas' and public.puede_subir_documento(name))
  with check (bucket_id='documentos-granjas' and public.puede_subir_documento(name));
create policy documentos_leer on storage.objects for select to authenticated
  using (bucket_id='documentos-granjas' and public.puede_leer_documento(name));

-- Una ruta guardada no puede apuntar al documento de otra granja ni a un archivo inexistente.
create function public.validar_documento_granja()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.documentos_terreno like 'storage/%' and
    (split_part(new.documentos_terreno,'/',3) <> new.id::text or not exists (
      select 1 from storage.objects o where o.bucket_id='documentos-granjas'
        and o.name=substring(new.documentos_terreno from 9)
    )) then
    raise exception 'El archivo no corresponde a esta granja o no terminó de subir';
  end if;
  return new;
end;
$$;
revoke all on function public.validar_documento_granja() from public,anon,authenticated;
create trigger validar_documento_granja before insert or update of documentos_terreno on public.granjas
for each row execute function public.validar_documento_granja();
notify pgrst,'reload schema';
commit;
