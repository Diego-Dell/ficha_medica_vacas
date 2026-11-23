-- Primero se sube el PDF privado; después se crea la granja y su vínculo.
begin;
update storage.buckets set allowed_mime_types=array['application/pdf']
where id='documentos-granjas';

create or replace function public.crear_cuenta_nueva()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  insert into public.cuentas(id,identificador,nombre)
  values(new.id,coalesce(new.email,new.id::text),nullif(btrim(new.raw_user_meta_data->>'nombre'),''));
  -- Los datos de la granja siguen en los metadatos hasta confirmar el correo y subir el PDF.
  return new;
end;
$$;

create or replace function public.puede_subir_documento(p_ruta text)
returns boolean language sql stable security definer set search_path='' as $$
  select split_part(p_ruta,'/',1)=auth.uid()::text
    and split_part(p_ruta,'/',2) ~ '^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$'
    and lower(p_ruta) like '%.pdf'
    and exists(select 1 from public.cuentas where id=auth.uid() and activa)
    and (
      not exists(select 1 from public.granjas where id::text=split_part(p_ruta,'/',2))
      or exists(select 1 from public.granjas g join public.vinculaciones v on v.granja_id=g.id
        where g.id::text=split_part(p_ruta,'/',2) and v.cuenta_id=auth.uid()
          and v.activa and v.rol='dueno' and not g.confirmada and g.motivo_rechazo is null)
    );
$$;

create or replace function public.puede_leer_documento(p_ruta text)
returns boolean language sql stable security definer set search_path='' as $$
  select (split_part(p_ruta,'/',1)=auth.uid()::text
    and exists(select 1 from public.cuentas where id=auth.uid() and activa)
    and not exists(select 1 from public.granjas where id::text=split_part(p_ruta,'/',2)))
  or exists(select 1 from public.granjas g where g.id::text=split_part(p_ruta,'/',2) and (
    (public.es_administrador() and g.documentos_terreno='storage/'||p_ruta)
    or exists(select 1 from public.vinculaciones v join public.cuentas c on c.id=v.cuenta_id
      where v.granja_id=g.id and v.cuenta_id=auth.uid() and v.rol='dueno'
        and v.activa and c.activa and split_part(p_ruta,'/',1)=auth.uid()::text)));
$$;

create or replace function public.registrar_granja(p_nombre text,p_hectareas numeric,p_runsa text,p_documentos text,p_trabajadores integer default 0)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_granja uuid; v_ruta text := substring(p_documentos from 9);
begin
  if auth.uid() is null or not exists(select 1 from public.cuentas where id=auth.uid() and activa) then
    raise exception 'Hace falta una cuenta activa';
  end if;
  if p_documentos not like 'storage/%' or split_part(v_ruta,'/',1)<>auth.uid()::text then
    raise exception 'Primero subí el PDF de tu granja';
  end if;
  v_granja := split_part(v_ruta,'/',2)::uuid;
  perform pg_advisory_xact_lock(hashtextextended(v_granja::text,0));
  if exists(select 1 from public.granjas where id=v_granja) then
    if exists(select 1 from public.granjas g join public.vinculaciones v on v.granja_id=g.id
      where g.id=v_granja and g.documentos_terreno=p_documentos and v.cuenta_id=auth.uid() and v.activa and v.rol='dueno') then
      return v_granja;
    end if;
    raise exception 'El documento no corresponde a un nuevo registro';
  end if;
  insert into public.granjas(id,nombre,hectareas,runsa,documentos_terreno,trabajadores)
  values(v_granja,p_nombre,p_hectareas,p_runsa,p_documentos,p_trabajadores);
  insert into public.vinculaciones(cuenta_id,granja_id,rol) values(auth.uid(),v_granja,'dueno');
  return v_granja;
end;
$$;

create function public.exigir_pdf_granja()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if new.documentos_terreno is null or new.documentos_terreno not like 'storage/%'
    or not exists(select 1 from storage.objects o where o.bucket_id='documentos-granjas'
      and o.name=substring(new.documentos_terreno from 9)
      and split_part(o.name,'/',2)=new.id::text
      and lower(o.name) like '%.pdf' and o.metadata->>'mimetype'='application/pdf'
      and (o.metadata->>'size')::bigint between 1 and 10485760) then
    raise exception 'No se puede registrar ni aprobar la granja sin un PDF subido';
  end if;
  return new;
end;
$$;
revoke all on function public.exigir_pdf_granja() from public,anon,authenticated;
create trigger exigir_pdf_al_registrar before insert on public.granjas
for each row execute function public.exigir_pdf_granja();
create trigger exigir_pdf_al_aprobar before update of confirmada on public.granjas
for each row when (new.confirmada and not old.confirmada) execute function public.exigir_pdf_granja();
notify pgrst,'reload schema';
commit;
