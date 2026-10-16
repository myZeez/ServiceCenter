-- Koreksi migrasi 0044.
--
-- 0044 mengisi waktu sekarang untuk arsip yang sudah berstatus keluar tetapi
-- tidak pernah memiliki cap waktu. Ini membuat 1.088 nota lama tampak keluar
-- pada hari migrasi. Tanggal tidak boleh ditebak dari waktu perbaikan.

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

  if tg_op = 'UPDATE'
     and old.status in ('selesai', 'diambil', 'batal')
     and new.status in ('masuk', 'dikerjakan', 'tunggu_part', 'dikirim_cabang')
  then
    new.tanggal_selesai := null;
  end if;

  -- Waktu sekarang hanya boleh lahir pada nota baru atau saat statusnya
  -- benar-benar pindah ke luar toko. Arsip lama tanpa cap waktu dibiarkan
  -- kosong sampai ada bukti tanggal yang sah dari sumber historinya.
  if new.status in ('diambil', 'batal') then
    if tg_op = 'INSERT'
       or (tg_op = 'UPDATE' and old.status is distinct from new.status)
       or (tg_op = 'UPDATE'
           and new.waktu_diambil is not null
           and new.waktu_diambil is distinct from old.waktu_diambil)
    then
      new.waktu_diambil := coalesce(new.waktu_diambil, now());
      new.tanggal_diambil := hari_laporan(new.waktu_diambil);
    elsif new.waktu_diambil is not null then
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

-- Satu cap waktu yang sama persis menandai 1.088 baris yang disentuh oleh
-- migrasi 0044. Trigger dimatikan hanya saat membatalkan cap palsu itu agar
-- ia tidak membuat cap baru pada baris yang sedang dipulihkan.
alter table public.service_orders disable trigger trg_so_touch;

update public.service_orders
set tanggal_diambil = null,
    waktu_diambil = null
where tanggal_diambil = date '2026-09-28'
  and waktu_diambil = timestamptz '2026-09-27 10:04:08.928063+00'
  and updated_at = timestamptz '2026-09-27 10:04:08.928063+00';

alter table public.service_orders enable trigger trg_so_touch;

commit;
