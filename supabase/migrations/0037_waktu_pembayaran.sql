-- =====================================================================
--  Migrasi 0037 : waktu pembayaran
--
--  tanggal_lunas adalah HARI LAPORAN, bukan saat pembayaran sebenarnya.
--  Mengubahnya menjadi timestamp akan memindahkan rekap lama, terutama
--  pembayaran sesudah jam tutup. Karena itu jam baru disimpan di kolom
--  waktu_lunas, sementara tanggal_lunas tetap menjadi tanggal laporan.
-- =====================================================================

alter table service_orders
  add column if not exists waktu_lunas timestamptz;

comment on column service_orders.waktu_lunas is
  'Saat pembayaran sebenarnya. Diisi server untuk pelunasan otomatis, atau '
  'dari pilihan tanggal dan jam admin untuk pembayaran manual. Null pada '
  'arsip lama yang hanya mempunyai tanggal_lunas.';

create index if not exists so_waktu_lunas
  on service_orders (waktu_lunas desc)
  where waktu_lunas is not null;

-- Pembayaran yang dicap otomatis (nota diambil/batal berbiaya, bukan
-- piutang) memakai now() dari PostgreSQL. Jadi waktunya adalah waktu server,
-- bukan jam perangkat yang mungkin salah. Pilihan manual dari aplikasi tetap
-- dihormati karena ia sudah mengirim tanggal_lunas dan waktu_lunas.
create or replace function sentuh_service_order()
returns trigger
language plpgsql security definer set search_path = public as $fn$
begin
  new.updated_at := now();

  if (new.status = 'diambil' or (new.status = 'batal' and new.biaya > 0))
     and new.cara_bayar is not null
     and new.tanggal_lunas is null
     and not coalesce(
       (select m.piutang from metode_bayar m where m.kode = new.cara_bayar),
       false
     )
  then
    new.waktu_lunas := coalesce(new.waktu_lunas, now());
    new.tanggal_lunas := hari_laporan(new.waktu_lunas);
  end if;

  -- Tanggal lunas kosong berarti belum ada pembayaran; waktu lama tidak
  -- boleh tertinggal dan membuatnya terlihat sudah dilunasi.
  if new.tanggal_lunas is null then
    new.waktu_lunas := null;
  end if;

  if old.status = 'batal'
     and new.status::text in ('masuk', 'dikerjakan', 'tunggu_part', 'dikirim_cabang')
  then
    new.tanggal_selesai := null;
  end if;

  if new.status in ('selesai', 'diambil', 'batal')
     and new.tanggal_selesai is null
  then
    new.tanggal_selesai := hari_laporan();
  end if;

  return new;
end;
$fn$;

-- waktu_lunas termasuk data pembayaran; teknisi tidak boleh mengubahnya.
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
        new.waktu_lunas, new.created_by)
       is distinct from
       (old.no_nota, old.tanggal_masuk, old.customer_nama, old.customer_telp,
        old.customer_email, old.customer_id, old.barang_nama, old.barang_type,
        old.barang_sn, old.biaya, old.cara_bayar, old.tanggal_lunas,
        old.waktu_lunas, old.created_by)
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

select 'kolom waktu pembayaran' as pemeriksaan,
       case when exists (
         select 1 from information_schema.columns
         where table_schema = 'public' and table_name = 'service_orders'
           and column_name = 'waktu_lunas'
       ) then 'ada' else 'TIDAK ADA' end as hasil
union all
select 'trigger pembayaran',
       case when exists (
         select 1 from pg_proc
         where proname = 'sentuh_service_order'
           and prosrc ilike '%waktu_lunas%'
       ) then 'versi 0037' else 'MASIH VERSI LAMA' end;
