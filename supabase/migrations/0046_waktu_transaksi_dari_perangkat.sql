-- Waktu transaksi berasal dari perangkat yang menyimpan nota.
--
-- Jangan gunakan now() sebagai cadangan untuk waktu_diambil atau
-- waktu_lunas. Lokasi server dapat berbeda dari lokasi toko; aplikasi
-- mengirim tanggal dan jam perangkat secara eksplisit. Fallback
-- hari_laporan(waktu) hanya dipakai untuk klien lama yang mengirim jam
-- namun belum mengirim kolom tanggalnya.

begin;

create or replace function public.sentuh_service_order()
returns trigger
language plpgsql security definer set search_path = public as $fn$
begin
  new.updated_at := now();

  -- Pelunasan piutang atau nota tanpa pelunasan tidak boleh meninggalkan
  -- cap waktu lama. Untuk pembayaran nyata, tanggal dari aplikasi dihormati;
  -- hari_laporan hanya cadangan data dari klien versi lama.
  if new.tanggal_lunas is null then
    if new.waktu_lunas is not null
       and new.cara_bayar is not null
       and not coalesce(
         (select m.piutang from metode_bayar m where m.kode = new.cara_bayar),
         false
       )
    then
      new.tanggal_lunas := hari_laporan(new.waktu_lunas);
    else
      new.waktu_lunas := null;
    end if;
  end if;

  if tg_op = 'UPDATE'
     and old.status in ('selesai', 'diambil', 'batal')
     and new.status in ('masuk', 'dikerjakan', 'tunggu_part', 'dikirim_cabang')
  then
    new.tanggal_selesai := null;
  end if;

  -- Diambil dan Batal sama-sama berarti unit keluar. Tidak ada jam server
  -- yang dibuat di sini: bila aplikasi belum mengirim waktu, kolomnya tetap
  -- kosong agar data tidak dipalsukan. Tanggal perangkat yang dikirim
  -- aplikasi dipertahankan apa adanya.
  if new.status in ('diambil', 'batal') then
    if new.tanggal_diambil is null and new.waktu_diambil is not null then
      new.tanggal_diambil := hari_laporan(new.waktu_diambil);
    end if;
  elsif tg_op = 'UPDATE' and old.status in ('diambil', 'batal') then
    new.tanggal_diambil := null;
    new.waktu_diambil := null;
  end if;

  if new.status in ('selesai', 'diambil', 'batal')
     and new.tanggal_selesai is null
  then
    new.tanggal_selesai := hari_laporan();
  end if;

  return new;
end;
$fn$;

commit;
