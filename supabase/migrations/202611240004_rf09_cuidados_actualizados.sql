-- RF-05 incorporó estas tablas después del paquete inicial de RF-09.
begin;
alter table public.observaciones_cuidados enable row level security;
alter table public.correcciones_cuidados enable row level security;
grant select, insert, update on public.observaciones_cuidados to authenticated;
grant select, insert on public.correcciones_cuidados to authenticated;

do $policies$
declare t text;
begin
  foreach t in array array['observaciones_cuidados','correcciones_cuidados'] loop
    execute format('drop policy if exists rf09_sesion_activa on public.%I',t);
    execute format('create policy rf09_sesion_activa on public.%I as restrictive for all to authenticated using ((select public.rf09_cuenta_activa())) with check ((select public.rf09_cuenta_activa()))',t);
    execute format('drop policy if exists rf09_admin_ver on public.%I',t);
    execute format('create policy rf09_admin_ver on public.%I for select to authenticated using (public.rf09_admin_ficha(ficha_id))',t);
    execute format('drop trigger if exists rf09_auditar_admin on public.%I',t);
    execute format('create trigger rf09_auditar_admin after insert or update or delete on public.%I for each row execute function public.rf09_registrar_cambio_administrador()',t);
  end loop;
end;
$policies$;

drop policy if exists rf09_admin_crear on public.observaciones_cuidados;
create policy rf09_admin_crear on public.observaciones_cuidados for insert to authenticated
  with check (public.rf09_admin_ficha(ficha_id) and registrado_por=auth.uid());
drop policy if exists rf09_admin_editar on public.observaciones_cuidados;
create policy rf09_admin_editar on public.observaciones_cuidados for update to authenticated
  using (public.rf09_admin_ficha(ficha_id)) with check (public.rf09_admin_ficha(ficha_id));
drop policy if exists rf09_admin_crear on public.correcciones_cuidados;
create policy rf09_admin_crear on public.correcciones_cuidados for insert to authenticated
  with check (public.rf09_admin_ficha(ficha_id) and corregido_por=auth.uid());
drop trigger if exists rf09_conservar_autoria on public.observaciones_cuidados;
create trigger rf09_conservar_autoria before update on public.observaciones_cuidados
  for each row execute function public.rf09_conservar_autoria();
drop trigger if exists rf09_sin_eventos_tras_baja on public.observaciones_cuidados;
create trigger rf09_sin_eventos_tras_baja before insert on public.observaciones_cuidados
  for each row execute function public.rechazar_si_animal_de_baja();
commit;
