-- VetLink / RF-09 / Paso 1: ejecutar en SQL Editor de Supabase como postgres.
-- Preparado a partir de los CSV entregados. No ejecutado por Codex.
-- No cambia las políticas ni las validaciones de las tablas del proyecto.
begin;

create table if not exists public.auditoria_administrador (
  id uuid primary key default gen_random_uuid(),
  fecha_hora timestamptz not null default clock_timestamp(),
  administrador_id uuid not null,
  tabla text not null,
  registro_id uuid not null,
  granja_id uuid,
  operacion text not null check (operacion in ('INSERT', 'UPDATE', 'DELETE')),
  datos_anteriores jsonb,
  datos_nuevos jsonb
);

-- Sin FK a cuentas: la evidencia se conserva aunque se elimine una cuenta.
create index if not exists auditoria_administrador_fecha_idx
  on public.auditoria_administrador (fecha_hora desc);
create index if not exists auditoria_administrador_registro_idx
  on public.auditoria_administrador (tabla, registro_id);

alter table public.auditoria_administrador enable row level security;
revoke all on table public.auditoria_administrador from public, anon, authenticated;
grant select on table public.auditoria_administrador to authenticated;

drop policy if exists rf09_auditoria_lectura on public.auditoria_administrador;
create policy rf09_auditoria_lectura
  on public.auditoria_administrador for select to authenticated
  using ((select public.es_administrador()));

create or replace function public.rf09_registrar_cambio_administrador()
returns trigger
language plpgsql
security definer
set search_path = ''
as $func$
declare
  actor uuid := auth.uid();
  es_admin boolean;
  anterior jsonb;
  nuevo jsonb;
  referencia jsonb;
  granja uuid;
begin
  -- SQL Editor, migraciones y tareas sin identidad de usuario no se atribuyen
  -- artificialmente a un administrador de la aplicación.
  if actor is null then
    return null;
  end if;

  if tg_op <> 'INSERT' then anterior := to_jsonb(old); end if;
  if tg_op <> 'DELETE' then nuevo := to_jsonb(new); end if;

  es_admin := public.es_administrador();
  -- Si el administrador desactiva su propia cuenta, es_administrador()
  -- ya devuelve false en AFTER UPDATE. Se comprueba también el estado anterior.
  if tg_table_name = 'cuentas' and tg_op in ('UPDATE', 'DELETE') then
    if (anterior ->> 'id')::uuid = actor
       and coalesce((anterior ->> 'administrador_tecnico')::boolean, false)
       and coalesce((anterior ->> 'activa')::boolean, false) then
      es_admin := true;
    end if;
  end if;
  if not coalesce(es_admin, false) then return null; end if;

  -- Evita registrar escrituras que no cambian datos de la fila.
  if tg_op = 'UPDATE' and anterior is not distinct from nuevo then
    return null;
  end if;

  referencia := coalesce(nuevo, anterior);
  if tg_table_name = 'granjas' then
    granja := (referencia ->> 'id')::uuid;
  elsif referencia ? 'granja_id' then
    granja := (referencia ->> 'granja_id')::uuid;
  elsif referencia ? 'ficha_id' then
    select f.granja_id into granja
    from public.fichas_bovinas f
    where f.id = (referencia ->> 'ficha_id')::uuid;
  end if;

  -- En cuentas solo se guardan los datos administrativos necesarios.
  if tg_table_name = 'cuentas' then
    if anterior is not null then
      select jsonb_object_agg(e.key, e.value) into anterior
      from jsonb_each(anterior) e
      where e.key in ('id','nombre','activa','administrador_tecnico');
    end if;
    if nuevo is not null then
      select jsonb_object_agg(e.key, e.value) into nuevo
      from jsonb_each(nuevo) e
      where e.key in ('id','nombre','activa','administrador_tecnico');
    end if;
  else
    anterior := anterior - array['clave_hash','password','password_hash',
      'token','token_hash','access_token','refresh_token','codigo','codigo_hash'];
    nuevo := nuevo - array['clave_hash','password','password_hash',
      'token','token_hash','access_token','refresh_token','codigo','codigo_hash'];
  end if;

  insert into public.auditoria_administrador
    (administrador_id, tabla, registro_id, granja_id, operacion,
     datos_anteriores, datos_nuevos)
  values
    (actor, tg_table_name, (referencia ->> 'id')::uuid, granja, tg_op,
     anterior, nuevo);

  return null; -- Es un trigger AFTER: el retorno no reemplaza la fila.
end;
$func$;

revoke all on function public.rf09_registrar_cambio_administrador()
  from public, anon, authenticated;

-- Conserva los triggers existentes. Solo sustituye el trigger propio de RF-09
-- si este mismo archivo se vuelve a ejecutar.
do $instalar$
declare tabla text;
begin
  foreach tabla in array array[
    'cuentas','granjas','vinculaciones','invitaciones','fichas_bovinas',
    'atenciones_clinicas','eventos_reproductivos','tratamientos',
    'prevenciones','cuidados','aplicaciones','correcciones_registros'
  ] loop
    execute format('drop trigger if exists rf09_auditar_admin on public.%I', tabla);
    execute format(
      'create trigger rf09_auditar_admin after insert or update or delete '
      'on public.%I for each row execute function '
      'public.rf09_registrar_cambio_administrador()', tabla
    );
  end loop;
end;
$instalar$;

commit;
