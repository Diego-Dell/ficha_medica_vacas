-- Aplicar DESPUÉS de 01_registro_cambios.sql en Supabase SQL Editor (postgres).
begin;

create or replace function public.rf09_cuenta_activa()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.cuentas c where c.id=auth.uid() and c.activa);
$$;
revoke all on function public.rf09_cuenta_activa() from public,anon;
grant execute on function public.rf09_cuenta_activa() to authenticated;

-- Una sesión de Auth todavía puede existir después de desactivar la cuenta.
-- Esta política restrictiva impide que conserve el acceso a los datos.
do $active$
declare t text;
begin
  foreach t in array array['cuentas','granjas','vinculaciones','invitaciones',
    'fichas_bovinas','atenciones_clinicas','eventos_reproductivos',
    'tratamientos','prevenciones','aplicaciones','cuidados'] loop
    execute format('drop policy if exists rf09_sesion_activa on public.%I',t);
    execute format('create policy rf09_sesion_activa on public.%I as restrictive for all to authenticated using ((select public.rf09_cuenta_activa())) with check ((select public.rf09_cuenta_activa()))',t);
  end loop;
end;
$active$;

create or replace function public.rf09_admin_granja(p_granja uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.es_administrador() and exists (
    select 1 from public.granjas g
    where g.id = p_granja and g.confirmada and g.motivo_rechazo is null
  );
$$;
create or replace function public.rf09_admin_ficha(p_ficha uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.fichas_bovinas f
    where f.id = p_ficha and public.rf09_admin_granja(f.granja_id));
$$;
revoke all on function public.rf09_admin_granja(uuid), public.rf09_admin_ficha(uuid) from public, anon;
grant execute on function public.rf09_admin_granja(uuid), public.rf09_admin_ficha(uuid) to authenticated;

-- Se agregan políticas propias; no se reemplazan las políticas de otros roles.
do $policies$
declare t text; autor text;
begin
  foreach t in array array['cuentas','granjas','vinculaciones'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('grant select, update on public.%I to authenticated', t);
    execute format('drop policy if exists rf09_admin_ver on public.%I', t);
    execute format('create policy rf09_admin_ver on public.%I for select to authenticated using ((select public.es_administrador()))', t);
    execute format('drop policy if exists rf09_admin_editar on public.%I', t);
    execute format('create policy rf09_admin_editar on public.%I for update to authenticated using ((select public.es_administrador())) with check ((select public.es_administrador()))', t);
  end loop;

  alter table public.fichas_bovinas enable row level security;
  grant select, insert, update on public.fichas_bovinas to authenticated;
  drop policy if exists rf09_admin_ver on public.fichas_bovinas;
  create policy rf09_admin_ver on public.fichas_bovinas for select to authenticated
    using (public.rf09_admin_granja(granja_id));
  drop policy if exists rf09_admin_crear on public.fichas_bovinas;
  create policy rf09_admin_crear on public.fichas_bovinas for insert to authenticated
    with check (public.rf09_admin_granja(granja_id) and fecha_baja is null);
  drop policy if exists rf09_admin_editar on public.fichas_bovinas;
  create policy rf09_admin_editar on public.fichas_bovinas for update to authenticated
    using (public.rf09_admin_granja(granja_id))
    with check (public.rf09_admin_granja(granja_id));

  foreach t in array array['atenciones_clinicas','eventos_reproductivos',
    'tratamientos','prevenciones','aplicaciones','cuidados'] loop
    autor := case t when 'tratamientos' then 'prescrito_por'
      when 'prevenciones' then 'programado_por'
      when 'aplicaciones' then 'aplicado_por' else 'registrado_por' end;
    execute format('alter table public.%I enable row level security', t);
    execute format('grant select, insert, update on public.%I to authenticated', t);
    execute format('drop policy if exists rf09_admin_ver on public.%I', t);
    execute format('create policy rf09_admin_ver on public.%I for select to authenticated using (public.rf09_admin_ficha(ficha_id))', t);
    execute format('drop policy if exists rf09_admin_crear on public.%I', t);
    execute format('create policy rf09_admin_crear on public.%I for insert to authenticated with check (public.rf09_admin_ficha(ficha_id) and %I = auth.uid())', t, autor);
    execute format('drop policy if exists rf09_admin_editar on public.%I', t);
    execute format('create policy rf09_admin_editar on public.%I for update to authenticated using (public.rf09_admin_ficha(ficha_id)) with check (public.rf09_admin_ficha(ficha_id))', t);
  end loop;

  -- La exportación no incluía políticas para cuidados. Mantiene el acceso normal
  -- de los miembros y exige que el autor sea la persona que inició sesión.
  drop policy if exists rf09_cuidados_miembros_ver on public.cuidados;
  create policy rf09_cuidados_miembros_ver on public.cuidados for select to authenticated
    using (public.rol_en_ficha(ficha_id) is not null);
  drop policy if exists rf09_cuidados_miembros_crear on public.cuidados;
  create policy rf09_cuidados_miembros_crear on public.cuidados for insert to authenticated
    with check (public.rol_en_ficha(ficha_id) is not null and registrado_por = auth.uid());

  alter table public.invitaciones enable row level security;
  grant select, insert, update on public.invitaciones to authenticated;
  drop policy if exists rf09_admin_ver on public.invitaciones;
  create policy rf09_admin_ver on public.invitaciones for select to authenticated
    using ((select public.es_administrador()));
  drop policy if exists rf09_admin_crear on public.invitaciones;
  create policy rf09_admin_crear on public.invitaciones for insert to authenticated
    with check (public.rf09_admin_granja(granja_id) and emitida_por = auth.uid());
  drop policy if exists rf09_admin_editar on public.invitaciones;
  create policy rf09_admin_editar on public.invitaciones for update to authenticated
    using (public.rf09_admin_granja(granja_id))
    with check (public.rf09_admin_granja(granja_id));
end;
$policies$;

-- Los cambios de cuenta no permiten darse privilegios ni modificar su identidad.
create or replace function public.rf09_proteger_cuenta()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then return new; end if;
  if (to_jsonb(new) - array['nombre','activa']) is distinct from
     (to_jsonb(old) - array['nombre','activa']) then
    raise exception 'La identidad y la marca de administrador no se editan desde la aplicación' using errcode='42501';
  end if;
  if new.activa is distinct from old.activa and not public.es_administrador() then
    raise exception 'Solo el administrador cambia el estado de una cuenta' using errcode='42501';
  end if;
  if old.id = auth.uid() and old.administrador_tecnico and not new.activa then
    raise exception 'No podés desactivar tu propia cuenta administradora';
  end if;
  return new;
end;
$$;
revoke all on function public.rf09_proteger_cuenta() from public, anon, authenticated;
drop trigger if exists rf09_proteger_cuenta on public.cuentas;
create trigger rf09_proteger_cuenta before update on public.cuentas
for each row execute function public.rf09_proteger_cuenta();

-- El administrador activa/desactiva vinculaciones, sin reasignarlas a otra
-- cuenta o granja ni inventar roles nuevos.
create or replace function public.rf09_proteger_vinculacion()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is not null and public.es_administrador()
     and (to_jsonb(new) - 'activa') is distinct from (to_jsonb(old) - 'activa') then
    raise exception 'Solo se permite cambiar el estado de la vinculación' using errcode='42501';
  end if;
  return new;
end;
$$;
revoke all on function public.rf09_proteger_vinculacion() from public, anon, authenticated;
drop trigger if exists rf09_proteger_vinculacion on public.vinculaciones;
create trigger rf09_proteger_vinculacion before update on public.vinculaciones
for each row execute function public.rf09_proteger_vinculacion();

-- La autoría original se conserva aunque otro administrador corrija el registro.
create or replace function public.rf09_conservar_autoria()
returns trigger language plpgsql security definer set search_path = '' as $$
declare anterior jsonb; nuevo jsonb; autor text;
begin
  if auth.uid() is null then return new; end if;
  anterior := to_jsonb(old); nuevo := to_jsonb(new);
  autor := case tg_table_name when 'tratamientos' then 'prescrito_por'
    when 'prevenciones' then 'programado_por'
    when 'aplicaciones' then 'aplicado_por' else 'registrado_por' end;
  if nuevo -> 'id' is distinct from anterior -> 'id'
     or nuevo -> 'ficha_id' is distinct from anterior -> 'ficha_id'
     or nuevo -> autor is distinct from anterior -> autor then
    raise exception 'La ficha y la autoría originales deben conservarse' using errcode='42501';
  end if;
  return new;
end;
$$;
revoke all on function public.rf09_conservar_autoria() from public, anon, authenticated;
do $authors$
declare t text;
begin
  foreach t in array array['atenciones_clinicas','eventos_reproductivos',
    'tratamientos','prevenciones','aplicaciones','cuidados'] loop
    execute format('drop trigger if exists rf09_conservar_autoria on public.%I',t);
    execute format('create trigger rf09_conservar_autoria before update on public.%I for each row execute function public.rf09_conservar_autoria()',t);
  end loop;
end;
$authors$;

-- Agrega al administrador conservando las restricciones de los otros roles.
create or replace function public.validar_edicion_etapa_ficha()
returns trigger language plpgsql security definer set search_path = '' as $$
declare rol_actual text;
begin
  if auth.uid() is null then
    if current_setting('role',true) in ('authenticated','anon') then
      raise exception 'Se requiere una sesión' using errcode='42501';
    end if;
    return new;
  end if;
  if new.id is distinct from old.id or new.granja_id is distinct from old.granja_id then
    raise exception 'No se permite cambiar la identidad de la ficha' using errcode='42501';
  end if;
  if old.fecha_baja is not null then
    raise exception 'La ficha está dada de baja' using errcode='42501';
  end if;
  if public.rf09_admin_granja(old.granja_id) then return new; end if;
  select v.rol::text into rol_actual from public.vinculaciones v
    join public.cuentas c on c.id=v.cuenta_id
    join public.granjas g on g.id=v.granja_id
    where v.granja_id=old.granja_id and v.cuenta_id=auth.uid()
      and v.activa and c.activa and g.confirmada for share of v,c,g;
  if rol_actual='dueno' then return new; end if;
  if rol_actual='veterinario' then
    if (to_jsonb(new)-array['etapa','version']) is distinct from
       (to_jsonb(old)-array['etapa','version']) then
      raise exception 'El veterinario solo puede editar la etapa' using errcode='42501';
    end if;
    return new;
  end if;
  if rol_actual='trabajador' then
    if new.etapa is distinct from old.etapa or new.fecha_baja is distinct from old.fecha_baja
       or new.motivo_baja is distinct from old.motivo_baja then
      raise exception 'El trabajador no puede cambiar etapa ni registrar bajas' using errcode='42501';
    end if;
    return new;
  end if;
  raise exception 'Tu rol no permite editar la ficha' using errcode='42501';
end;
$$;
create or replace function public.proteger_baja()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is not null
    and (new.fecha_baja,new.motivo_baja) is distinct from (old.fecha_baja,old.motivo_baja)
    and not public.rf09_admin_granja(old.granja_id)
    and public.rol_en_granja(old.granja_id) is distinct from 'dueno' then
    raise exception 'Solo el dueño o el administrador puede dar de baja un animal' using errcode='42501';
  end if;
  return new;
end;
$$;
revoke all on function public.validar_edicion_etapa_ficha(),public.proteger_baja() from public,anon,authenticated;

-- Cuidados tampoco permite crear eventos nuevos sobre animales de baja.
drop trigger if exists rf09_sin_eventos_tras_baja on public.cuidados;
create trigger rf09_sin_eventos_tras_baja before insert on public.cuidados
for each row execute function public.rechazar_si_animal_de_baja();

-- Solo se confirma una solicitud pendiente. Rechazadas quedan fuera del listado.
create or replace function public.confirmar_granja(p_granja uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.es_administrador() then
    raise exception 'Solo el administrador puede confirmar granjas' using errcode='42501';
  end if;
  update public.granjas set confirmada=true
  where id=p_granja and not confirmada and motivo_rechazo is null;
  if not found then raise exception 'La solicitud no está pendiente'; end if;
end;
$$;
revoke all on function public.confirmar_granja(uuid) from public,anon;
grant execute on function public.confirmar_granja(uuid),public.rechazar_granja(uuid,text),public.es_administrador() to authenticated;

-- Lectura de los PDF para revisar solicitudes; no habilita subir o borrar PDF.
drop policy if exists rf09_admin_documentos_ver on storage.objects;
create policy rf09_admin_documentos_ver on storage.objects for select to authenticated
using (bucket_id='documentos-granjas' and (select public.es_administrador()));

commit;
