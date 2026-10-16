-- =====================================================================
-- Migrasi 0049 : admin dapat membatalkan tanda garansi pada nota
--
-- Klaim yang pernah dibuat tidak dihapus. Riwayatnya tetap diperlukan
-- untuk menelusuri part/masa garansi, tetapi statusnya menjadi batal dan
-- nota kembali menjadi servis biasa.
-- =====================================================================

create or replace function public.batalkan_garansi_nota(p_nota uuid)
returns text
language plpgsql volatile security definer
set search_path = public, pg_temp
as $fn$
declare
  v_nota public.service_orders%rowtype;
begin
  -- security definer melewati RLS: pembatalan ini hanya hak admin.
  if auth.uid() is null or not public.is_admin() then
    raise exception 'Hanya admin yang boleh membatalkan status garansi.'
      using errcode = '42501';
  end if;

  select * into v_nota
  from public.service_orders
  where id = p_nota
  for update;

  if not found then
    raise exception 'Nota servisnya tidak ditemukan.';
  end if;

  -- Aman bila respons sebelumnya hilang lalu aplikasi mencoba lagi.
  if not v_nota.garansi and v_nota.claim_id is null then
    return v_nota.no_nota;
  end if;

  if v_nota.claim_id is not null then
    update public.claims
    set
      status = 'batal',
      catatan = concat_ws(
        E'\n',
        nullif(btrim(catatan), ''),
        'Garansi pada nota ' || v_nota.no_nota ||
          ' dibatalkan oleh admin.'
      )
    where id = v_nota.claim_id;
  end if;

  -- Guard update service_orders hanya membuka dua kolom ini selama
  -- transaksi fungsi berlangsung.
  perform set_config('app.taut_klaim', 'on', true);
  update public.service_orders
  set garansi = false, claim_id = null
  where id = v_nota.id;
  perform set_config('app.taut_klaim', 'off', true);

  return v_nota.no_nota;
end;
$fn$;

comment on function public.batalkan_garansi_nota(uuid) is
  'Admin membatalkan tanda garansi nota, memutus tautannya, dan menandai klaim terkait sebagai batal tanpa menghapus riwayat.';

revoke all on function public.batalkan_garansi_nota(uuid) from public;
grant execute on function public.batalkan_garansi_nota(uuid) to authenticated;
