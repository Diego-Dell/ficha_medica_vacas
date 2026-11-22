-- Aplicar antes de publicar el backend. Conserva las políticas existentes.
begin;

-- Amplía el UPDATE al veterinario; el trigger limita exactamente las columnas.
create policy ficha_veterinario_actualiza_etapa
on public.fichas_bovinas for update to authenticated
using (exists (
  select 1 from public.vinculaciones v join public.cuentas c on c.id = v.cuenta_id
  join public.granjas g on g.id = v.granja_id
  where v.granja_id = fichas_bovinas.granja_id and v.cuenta_id = auth.uid()
    and v.activa and c.activa and g.confirmada and v.rol::text = 'veterinario'
))
with check (exists (
  select 1 from public.vinculaciones v join public.cuentas c on c.id = v.cuenta_id
  join public.granjas g on g.id = v.granja_id
  where v.granja_id = fichas_bovinas.granja_id and v.cuenta_id = auth.uid()
    and v.activa and c.activa and g.confirmada and v.rol::text = 'veterinario'
));

create function public.validar_edicion_etapa_ficha()
returns trigger language plpgsql security definer set search_path = '' as $$
declare rol_actual text;
begin
  -- Migraciones y mantenimiento con postgres/service_role siguen fuera del flujo de usuarios.
  if auth.uid() is null then
    if current_setting('role', true) in ('authenticated', 'anon') then
      raise exception 'Se requiere una sesión' using errcode = '42501';
    end if;
    return new;
  end if;
  select v.rol::text into rol_actual from public.vinculaciones v
    join public.cuentas c on c.id = v.cuenta_id
    join public.granjas g on g.id = v.granja_id
    where v.granja_id = old.granja_id and v.cuenta_id = auth.uid()
      and v.activa and c.activa and g.confirmada
    for share of v, c, g;
  if rol_actual is null or new.id is distinct from old.id
      or new.granja_id is distinct from old.granja_id then
    raise exception 'No se permite editar esta ficha' using errcode = '42501';
  end if;
  if old.fecha_baja is not null then
    raise exception 'La ficha está dada de baja' using errcode = '42501';
  end if;
  if rol_actual = 'dueno' then return new; end if;
  if rol_actual = 'veterinario' then
    if (to_jsonb(new) - array['etapa','version']) is distinct from
        (to_jsonb(old) - array['etapa','version']) then
      raise exception 'El veterinario solo puede editar la etapa' using errcode = '42501';
    end if;
    return new;
  end if;
  if rol_actual = 'trabajador' then
    if new.etapa is distinct from old.etapa or new.fecha_baja is distinct from old.fecha_baja
       or new.motivo_baja is distinct from old.motivo_baja then
      raise exception 'El trabajador no puede cambiar etapa ni registrar bajas' using errcode = '42501';
    end if;
    return new;
  end if;
  raise exception 'Tu rol no permite editar la ficha' using errcode = '42501';
end;
$$;
revoke all on function public.validar_edicion_etapa_ficha() from public;
create trigger validar_edicion_etapa_ficha before update on public.fichas_bovinas
for each row execute function public.validar_edicion_etapa_ficha();
commit;
