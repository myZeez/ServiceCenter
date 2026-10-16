-- =====================================================================
--  Migrasi 0036 : Garansi gratis dan status biaya kirim cabang
--
--  Garansi toko tidak ditagihkan ke brand; pekerjaan garansi pada
--  dasarnya gratis. Aplikasi mengunci biaya kecuali admin menandai ada
--  layanan atau part tambahan. Kolom ini hanya menyimpan penanda untuk
--  pengiriman cabang: gratis atau berbiaya, bukan nominal tagihan.
-- =====================================================================

alter table service_orders
  add column if not exists biaya_dikirim_cabang boolean;

comment on column service_orders.biaya_dikirim_cabang is
  'Pilihan pada status dikirim_cabang: false = tanpa biaya, true = ada biaya. '
  'Null hanya untuk arsip lama yang belum pernah diklasifikasikan.';

-- Catatan pengiriman baru harus jelas gratis atau berbiaya. NOT VALID
-- menjaga arsip yang sudah ada: data lama tidak ditebak atau diubah diam-
-- diam, tetapi penulisan baru tetap wajib memenuhi aturan ini.
do $batas$
begin
  alter table service_orders drop constraint if exists kirim_cabang_biaya_jelas;
  alter table service_orders add constraint kirim_cabang_biaya_jelas
    check (
      status::text <> 'dikirim_cabang'
      or biaya_dikirim_cabang is not null
    ) not valid;
end
$batas$;

-- Penanda ini adalah keadaan operasional pengiriman, bukan jumlah biaya.
-- Teknisi boleh memilihnya bersama cabang dan tanggal kirim; nominal,
-- cara bayar, dan tanggal lunas tetap dijaga trigger sebagai urusan admin.
create or replace function service_orders_guard_update()
returns trigger
language plpgsql security definer set search_path = public as $fn$
declare
  menaut boolean :=
    coalesce(current_setting('app.taut_klaim', true), 'off') = 'on';
begin
  if not ubah_kolom_bebas() then
    if (new.no_nota, new.tanggal_masuk, new.customer_nama, new.customer_telp,
        new.customer_email, new.customer_id, new.barang_nama, new.barang_type,
        new.barang_sn, new.biaya, new.cara_bayar, new.tanggal_lunas,
        new.created_by)
       is distinct from
       (old.no_nota, old.tanggal_masuk, old.customer_nama, old.customer_telp,
        old.customer_email, old.customer_id, old.barang_nama, old.barang_type,
        old.barang_sn, old.biaya, old.cara_bayar, old.tanggal_lunas,
        old.created_by)
    then
      raise exception 'Teknisi hanya boleh mengubah status dan catatan '
                      'pekerjaan. Biaya dan data nota diubah admin.';
    end if;

    if not menaut
       and (new.garansi, new.claim_id)
           is distinct from (old.garansi, old.claim_id)
    then
      raise exception 'Tanda garansi pada nota diubah lewat klaimnya, '
                      'bukan dengan menyunting nota.';
    end if;
  end if;

  return new;
end;
$fn$;

select 'kolom biaya pengiriman' as pemeriksaan,
       case when exists (
         select 1 from information_schema.columns
         where table_schema = 'public' and table_name = 'service_orders'
           and column_name = 'biaya_dikirim_cabang'
       ) then 'ada' else 'TIDAK ADA' end as hasil
union all
select 'batasan biaya pengiriman',
       case when exists (
         select 1 from pg_constraint
         where conname = 'kirim_cabang_biaya_jelas'
       ) then 'ada' else 'TIDAK ADA' end;
