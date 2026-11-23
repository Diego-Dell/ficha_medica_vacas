-- Agrega retiro y reemplazo atómico al esquema PostgreSQL existente.
begin;

alter table public.tratamientos add column if not exists retiro text;
alter table public.tratamientos add column if not exists anterior_id uuid references public.tratamientos(id);
create unique index tratamiento_un_reemplazo on public.tratamientos(anterior_id) where anterior_id is not null;
alter table public.tratamientos add constraint tratamiento_retiro_longitud check (retiro is null or length(retiro) <= 500);

-- No recibe un autor editable: siempre verifica auth.uid() y su vínculo vigente.
create function public.validar_veterinario_indicacion(p_ficha uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform 1 from public.fichas_bovinas f
    join public.granjas g on g.id = f.granja_id
    join public.vinculaciones v on v.granja_id = g.id
    join public.cuentas c on c.id = v.cuenta_id
    where f.id = p_ficha and f.fecha_baja is null and g.confirmada
      and v.cuenta_id = auth.uid() and v.rol::text = 'veterinario' and v.activa and c.activa
    for share of f, g, v, c;
  if not found then raise exception 'Solo un veterinario activo de la granja puede registrar en una ficha activa' using errcode = '42501'; end if;
end;
$$;

create function public.guardar_indicacion_tratamiento(
  p_ficha uuid, p_atencion uuid, p_datos jsonb,
  p_anterior uuid default null, p_version integer default null,
  p_fecha_fin date default null, p_motivo text default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  anterior public.tratamientos%rowtype;
  nueva uuid;
  inicio date := (p_datos->>'inicio')::date;
  dosis numeric := (p_datos->>'dosis')::numeric;
  fecha_atencion date;
begin
  perform public.validar_veterinario_indicacion(p_ficha);
  select (a.fecha at time zone 'America/La_Paz')::date into fecha_atencion
    from public.atenciones_clinicas a where a.id = p_atencion and a.ficha_id = p_ficha and not a.anulado for share;
  if not found then raise exception 'La atención debe estar vigente y pertenecer al mismo animal'; end if;
  if inicio is null or inicio < fecha_atencion then raise exception 'El inicio no puede ser anterior a la atención'; end if;
  if dosis is null or dosis < .001 or dosis > 9999999.999 or dosis::text in ('NaN','Infinity','-Infinity') then raise exception 'La dosis no es válida'; end if;
  if coalesce(length(btrim(p_datos->>'medicamento')),0) not between 1 and 200
    or coalesce(length(btrim(p_datos->>'unidad')),0) not between 1 and 30
    or coalesce(length(btrim(p_datos->>'via')),0) not between 1 and 60
    or coalesce(length(btrim(p_datos->>'frecuencia')),0) not between 1 and 100
    or coalesce(length(btrim(p_datos->>'duracion')),0) not between 1 and 100
    or coalesce(length(btrim(p_datos->>'retiro')),0) > 500 then raise exception 'Revisá los datos obligatorios y su longitud'; end if;
  if p_anterior is not null then
    select * into anterior from public.tratamientos where id = p_anterior for update;
    if not found or anterior.ficha_id <> p_ficha or anterior.atencion_id <> p_atencion
      or anterior.anulado or anterior.fecha_fin is not null or anterior.version is distinct from p_version then
      raise exception 'La indicación cambió. Actualizá el historial antes de reintentar' using errcode = '40001';
    end if;
    if p_fecha_fin is null or p_fecha_fin < anterior.inicio
      or p_fecha_fin > (now() at time zone 'America/La_Paz')::date or inicio < p_fecha_fin
      or coalesce(length(btrim(p_motivo)),0) not between 1 and 500 then raise exception 'Ingresá una fecha y un motivo de cierre válidos'; end if;
    update public.tratamientos set fecha_fin = p_fecha_fin, motivo_fin = btrim(p_motivo), version = version + 1 where id = p_anterior;
  elsif p_fecha_fin is not null or p_motivo is not null then
    raise exception 'Una nueva indicación comienza vigente';
  end if;
  insert into public.tratamientos(ficha_id, atencion_id, prescrito_por, medicamento, dosis,
    unidad, via, frecuencia, inicio, duracion, retiro, anterior_id)
    values (p_ficha, p_atencion, auth.uid(), btrim(p_datos->>'medicamento'), dosis,
      btrim(p_datos->>'unidad'), btrim(p_datos->>'via'), btrim(p_datos->>'frecuencia'), inicio,
      btrim(p_datos->>'duracion'), nullif(btrim(p_datos->>'retiro'),''), p_anterior)
    returning id into nueva;
  return nueva;
end;
$$;

create function public.finalizar_indicacion_tratamiento(p_tratamiento uuid, p_version integer, p_fecha_fin date, p_motivo text)
returns void language plpgsql security definer set search_path = '' as $$
declare anterior public.tratamientos%rowtype;
begin
  select * into anterior from public.tratamientos where id = p_tratamiento;
  if not found then raise exception 'La indicación no existe'; end if;
  perform public.validar_veterinario_indicacion(anterior.ficha_id);
  select * into anterior from public.tratamientos where id = p_tratamiento for update;
  if anterior.anulado or anterior.fecha_fin is not null or anterior.version is distinct from p_version then
    raise exception 'La indicación cambió. Actualizá el historial antes de reintentar' using errcode = '40001'; end if;
  if p_fecha_fin is null or p_fecha_fin < anterior.inicio or p_fecha_fin > (now() at time zone 'America/La_Paz')::date
    or coalesce(length(btrim(p_motivo)),0) not between 1 and 500 then raise exception 'Ingresá una fecha y un motivo de cierre válidos'; end if;
  update public.tratamientos set fecha_fin = p_fecha_fin, motivo_fin = btrim(p_motivo), version = version + 1 where id = p_tratamiento;
end;
$$;

-- Protege el historial incluso si un cliente antiguo intenta sobrescribirlo.
create function public.conservar_indicacion_tratamiento()
returns trigger language plpgsql set search_path = '' as $$
begin
  if tg_op = 'DELETE' then raise exception 'Los tratamientos se conservan como antecedentes'; end if;
  if (to_jsonb(new) - array['fecha_fin','motivo_fin','anulado','version']) is distinct from
      (to_jsonb(old) - array['fecha_fin','motivo_fin','anulado','version']) then
    raise exception 'Para modificar una indicación, cerrá la anterior y creá una nueva'; end if;
  if old.fecha_fin is not null and (new.fecha_fin is distinct from old.fecha_fin or new.motivo_fin is distinct from old.motivo_fin) then
    raise exception 'El cierre del tratamiento ya está registrado'; end if;
  if new.fecha_fin is not null and (new.fecha_fin < old.inicio or coalesce(length(btrim(new.motivo_fin)),0) not between 1 and 500) then
    raise exception 'El cierre requiere una fecha y un motivo válidos'; end if;
  return new;
end;
$$;
create trigger conservar_indicacion_tratamiento before update or delete on public.tratamientos
  for each row execute function public.conservar_indicacion_tratamiento();

-- Una pantalla del trabajador abierta antes del cierre tampoco puede aplicar la versión vieja.
create function public.validar_aplicacion_indicacion_vigente()
returns trigger language plpgsql security definer set search_path = '' as $$
declare indicacion public.tratamientos%rowtype; preventiva public.prevenciones%rowtype;
begin
  if new.anulado then return new; end if;
  if new.tratamiento_id is not null then
    select * into indicacion from public.tratamientos where id = new.tratamiento_id for share;
    if not found or indicacion.ficha_id <> new.ficha_id or indicacion.anulado or indicacion.fecha_fin is not null
      or (new.fecha_hora_real at time zone 'America/La_Paz')::date < indicacion.inicio then
      raise exception 'La indicación ya no está vigente. Actualizá las indicaciones del animal'; end if;
  end if;
  if new.prevencion_id is not null then
    select * into preventiva from public.prevenciones where id = new.prevencion_id for share;
    if not found or preventiva.ficha_id <> new.ficha_id or lower(preventiva.tipo::text) = 'control'
      or lower(preventiva.estado::text) = 'cancelada' then
      raise exception 'La prevención ya no admite aplicaciones'; end if;
  end if;
  return new;
end;
$$;
create trigger validar_aplicacion_indicacion_vigente before insert on public.aplicaciones
  for each row execute function public.validar_aplicacion_indicacion_vigente();

create function public.programar_prevencion(p_ficha uuid, p_tipo text, p_nombre text, p_fecha date)
returns uuid language plpgsql security definer set search_path = '' as $$
declare nueva uuid; fila public.prevenciones%rowtype;
begin
  perform public.validar_veterinario_indicacion(p_ficha);
  if p_tipo is null or p_tipo not in ('Vacuna','Desparasitacion','Control')
    or coalesce(length(btrim(p_nombre)),0) not between 1 and 200
    or p_fecha is null or p_fecha < (now() at time zone 'America/La_Paz')::date then
    raise exception 'Revisá el tipo, nombre y fecha programada'; end if;
  -- Usa el tipo de la columna existente tanto si es enum como texto.
  fila := jsonb_populate_record(null::public.prevenciones, jsonb_build_object('tipo',lower(p_tipo),'estado','pendiente'));
  insert into public.prevenciones(ficha_id, programado_por, tipo, nombre, fecha_programada, estado)
    values (p_ficha, auth.uid(), fila.tipo, btrim(p_nombre), p_fecha, fila.estado) returning id into nueva;
  return nueva;
end;
$$;

create function public.completar_control_preventivo(p_prevencion uuid, p_version integer, p_fecha timestamptz)
returns void language plpgsql security definer set search_path = '' as $$
declare anterior public.prevenciones%rowtype; fila public.prevenciones%rowtype;
begin
  select * into anterior from public.prevenciones where id = p_prevencion;
  if not found then raise exception 'El control no existe'; end if;
  perform public.validar_veterinario_indicacion(anterior.ficha_id);
  select * into anterior from public.prevenciones where id = p_prevencion for update;
  if lower(anterior.tipo::text) <> 'control' or lower(anterior.estado::text) <> 'pendiente' or anterior.version is distinct from p_version then
    raise exception 'El control cambió. Actualizá el historial antes de reintentar' using errcode = '40001'; end if;
  if p_fecha is null or p_fecha > now() then raise exception 'La fecha de realización no puede estar en el futuro'; end if;
  fila := jsonb_populate_record(null::public.prevenciones, '{"estado":"realizada"}'::jsonb);
  update public.prevenciones set estado = fila.estado, fecha_realizacion = p_fecha, version = version + 1 where id = p_prevencion;
end;
$$;

-- Lectura para los miembros activos de cada granja; las bajas conservan el historial.
create policy tratamientos_lectura_equipo on public.tratamientos for select to authenticated using (exists (
  select 1 from public.fichas_bovinas f join public.vinculaciones v on v.granja_id = f.granja_id
    join public.cuentas c on c.id = v.cuenta_id join public.granjas g on g.id = f.granja_id
    where f.id = tratamientos.ficha_id and v.cuenta_id = auth.uid() and v.activa and c.activa and g.confirmada
));
create policy prevenciones_lectura_equipo on public.prevenciones for select to authenticated using (exists (
  select 1 from public.fichas_bovinas f join public.vinculaciones v on v.granja_id = f.granja_id
    join public.cuentas c on c.id = v.cuenta_id join public.granjas g on g.id = f.granja_id
    where f.id = prevenciones.ficha_id and v.cuenta_id = auth.uid() and v.activa and c.activa and g.confirmada
));
grant select on public.tratamientos, public.prevenciones to authenticated;
revoke all on function public.validar_veterinario_indicacion(uuid) from public, anon, authenticated;
revoke all on function public.conservar_indicacion_tratamiento() from public, anon, authenticated;
revoke all on function public.validar_aplicacion_indicacion_vigente() from public, anon, authenticated;
revoke all on function public.guardar_indicacion_tratamiento(uuid,uuid,jsonb,uuid,integer,date,text) from public, anon;
revoke all on function public.finalizar_indicacion_tratamiento(uuid,integer,date,text) from public, anon;
revoke all on function public.programar_prevencion(uuid,text,text,date) from public, anon;
revoke all on function public.completar_control_preventivo(uuid,integer,timestamptz) from public, anon;
grant execute on function public.guardar_indicacion_tratamiento(uuid,uuid,jsonb,uuid,integer,date,text) to authenticated;
grant execute on function public.finalizar_indicacion_tratamiento(uuid,integer,date,text) to authenticated;
grant execute on function public.programar_prevencion(uuid,text,text,date) to authenticated;
grant execute on function public.completar_control_preventivo(uuid,integer,timestamptz) to authenticated;
notify pgrst, 'reload schema';
commit;
