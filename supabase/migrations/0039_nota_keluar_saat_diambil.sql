-- =====================================================================
-- Migrasi 0039: Nota keluar tercatat saat unit diambil pelanggan
--
-- `tanggal_selesai` adalah waktu pekerjaan teknisi selesai. Itu bukan
-- bukti unit telah keluar dari toko: unit dapat selesai pagi dan baru
-- diambil malam atau besok. Laporan Harian/Excel harus memakai saat
-- status nota benar-benar berubah menjadi `diambil`.
--
-- Hari laporan dihitung oleh hari_laporan(), yang membaca
-- store_settings.tutup_jam. Jadi jam yang admin atur di Pengaturan adalah
-- sumber aturan, bukan angka 17.00 yang tertanam di aplikasi/perangkat.
-- =====================================================================

begin;

alter table public.service_orders
  add column if not exists tanggal_diambil date,
  add column if not exists waktu_diambil timestamptz;

comment on column public.service_orders.tanggal_diambil is
  'Hari laporan ketika status nota menjadi diambil. Dasar Nota Keluar.';

comment on column public.service_orders.waktu_diambil is
  'Saat unit benar-benar ditandai diambil; dipakai untuk menghitung tanggal_diambil dengan tutup_jam.';

-- Arsip lama yang memang masih berstatus Diambil tidak boleh menghilang
-- dari laporan. Tanggal selesai lama adalah cadangan terbaik yang tersedia.
update public.service_orders
set tanggal_diambil = coalesce(tanggal_diambil, tanggal_selesai)
where status::text = 'diambil'
  and tanggal_diambil is null;

-- Jangan memakai partial predicate status::text di sini: PostgreSQL menolak
-- cast enum-ke-text pada predicate index karena fungsinya bukan IMMUTABLE.
-- Filter status tetap dilakukan oleh query laporan; indeks tanggal ini aman
-- untuk semua versi enum PostgreSQL.
create index if not exists so_diambil_harian
  on public.service_orders (tanggal_diambil desc);

create or replace function public.sentuh_service_order()
returns trigger
language plpgsql security definer set search_path = public as $fn$
begin
  new.updated_at := now();

  -- Pembayaran otomatis ketika unit diambil tetap memakai waktu server.
  -- hari_laporan() di bawah membaca tutup_jam dari Pengaturan.
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

  -- Membuka kembali nota berarti unit tidak lagi berada di laporan keluar
  -- maupun omset pekerjaan selesai. Cap lama tidak boleh tertinggal.
  if old.status::text in ('selesai', 'diambil', 'batal')
     and new.status::text in ('masuk', 'dikerjakan', 'tunggu_part', 'dikirim_cabang')
  then
    new.tanggal_selesai := null;
  end if;

  -- Ketika posisi unit pindah dari Sudah Diambil, hapus cap pengambilannya.
  if old.status = 'diambil' and new.status <> 'diambil' then
    new.tanggal_diambil := null;
    new.waktu_diambil := null;
  end if;

  -- Catat keluar hanya pada transisi ke Sudah Diambil. Bila aplikasi suatu
  -- saat mengirim waktu manual, nilai baru itu dihormati; selain itu pakai
  -- waktu server agar perangkat dengan jam salah tidak memalsukan laporan.
  if new.status = 'diambil' and old.status is distinct from 'diambil' then
    if new.waktu_diambil is not distinct from old.waktu_diambil then
      new.waktu_diambil := now();
    end if;
    new.tanggal_diambil := hari_laporan(new.waktu_diambil);
  end if;

  -- Pekerjaan selesai tetap memiliki capnya sendiri untuk omset teknisi.
  if new.status in ('selesai', 'diambil', 'batal')
     and new.tanggal_selesai is null
  then
    new.tanggal_selesai := hari_laporan();
  end if;

  return new;
end;
$fn$;

commit;