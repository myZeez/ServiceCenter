-- Tanggal laporan selalu diturunkan dari waktu perangkat yang dikirim.
--
-- Migrasi 0046 benar menghapus fallback jam server, tetapi terlalu
-- menghormati tanggal kalender yang dikirim aplikasi. Akibatnya transaksi
-- pukul 18.04 masih dapat bertanggal hari itu, padahal tutup jam 17.00.
-- Waktu tetap berasal dari perangkat; server hanya menerapkan aturan hari
-- kerja toko (tutup jam dan hari libur) pada waktu tersebut.

begin;

create or replace function public.sentuh_service_order()
returns trigger
language plpgsql security definer set search_path = public as $fn$
begin
  new.updated_at := now();

  if new.waktu_lunas is not null
     and new.cara_bayar is not null
     and not coalesce(
       (select m.piutang from metode_bayar m where m.kode = new.cara_bayar),
       false
     )
  then
    new.tanggal_lunas := hari_laporan(new.waktu_lunas);
  elsif new.tanggal_lunas is null then
    new.waktu_lunas := null;
  end if;

  if tg_op = 'UPDATE'
     and old.status in ('selesai', 'diambil', 'batal')
     and new.status in ('masuk', 'dikerjakan', 'tunggu_part', 'dikirim_cabang')
  then
    new.tanggal_selesai := null;
  end if;

  if new.status in ('diambil', 'batal') then
    if new.waktu_diambil is not null then
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
