-- =====================================================================
-- Migrasi 0041: pembatalan berarti unit sudah keluar dari toko
--
-- Status `batal` tetap menyimpan alasan administrasinya. Namun secara
-- fisik unit telah dikembalikan kepada pelanggan, sehingga tanggal dan
-- waktu keluarnya dicatat sama seperti status `diambil`.
-- =====================================================================

begin;

create or replace function public.sentuh_service_order()
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

  if new.tanggal_lunas is null then
    new.waktu_lunas := null;
  end if;

  if old.status::text in ('selesai', 'diambil', 'batal')
     and new.status::text in ('masuk', 'dikerjakan', 'tunggu_part', 'dikirim_cabang')
  then
    new.tanggal_selesai := null;
  end if;

  -- Diambil dan Batal sama-sama menandakan unit sudah keluar. Ketika
  -- kembali ke proses aktif, cap keluar dibuang agar tidak tetap muncul
  -- pada Nota Keluar.
  if old.status in ('diambil', 'batal')
     and new.status not in ('diambil', 'batal')
  then
    new.tanggal_diambil := null;
    new.waktu_diambil := null;
  end if;

  -- Catat waktu keluar saat unit Diambil atau dibatalkan. Waktu manual
  -- dari admin dihormati; jika kosong server memakai waktunya sendiri.
  if new.status in ('diambil', 'batal') and (
       old.status is distinct from new.status
       or new.waktu_diambil is distinct from old.waktu_diambil
     )
  then
    new.waktu_diambil := coalesce(new.waktu_diambil, now());
    new.tanggal_diambil := hari_laporan(new.waktu_diambil);
  end if;

  if new.status in ('selesai', 'diambil', 'batal')
     and new.tanggal_selesai is null
  then
    new.tanggal_selesai := hari_laporan();
  end if;

  return new;
end;
$fn$;

-- Arsip pembatalan lama belum memiliki cap keluar. Tanggal selesai adalah
-- cadangan historis paling akurat dan membuat laporan lama tetap lengkap.
update public.service_orders
set tanggal_diambil = coalesce(tanggal_diambil, tanggal_selesai)
where status = 'batal'
  and tanggal_diambil is null
  and tanggal_selesai is not null;

commit;
