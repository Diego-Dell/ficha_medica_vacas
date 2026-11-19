-- Adjuntar solo documentación de una solicitud propia pendiente, sin ampliar UPDATE de granjas.
begin;
create function public.adjuntar_documento_granja(p_granja uuid,p_ruta text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.puede_subir_documento(p_ruta) or split_part(p_ruta,'/',2)<>p_granja::text then
    raise exception 'Solo el dueño activo puede adjuntar documentos a su solicitud pendiente';
  end if;
  if not exists(select 1 from storage.objects where bucket_id='documentos-granjas' and name=p_ruta) then
    raise exception 'El documento todavía no terminó de subir';
  end if;
  update public.granjas set documentos_terreno='storage/'||p_ruta
    where id=p_granja and not confirmada and motivo_rechazo is null;
  if not found then raise exception 'La solicitud ya fue revisada'; end if;
end;
$$;
revoke all on function public.adjuntar_documento_granja(uuid,text) from public,anon;
grant execute on function public.adjuntar_documento_granja(uuid,text) to authenticated;
notify pgrst,'reload schema';
commit;
