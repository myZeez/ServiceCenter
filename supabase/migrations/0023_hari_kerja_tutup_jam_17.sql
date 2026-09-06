-- =====================================================================
--  Migrasi 0023 : hari kerja berganti jam 17.00, bukan tengah malam
--
--  Laporan harian ditutup dan dikirim ke pusat setiap jam 17.00. Unit
--  yang masuk sesudahnya tidak mungkin ikut di dalamnya, jadi ia tercatat
--  sebagai unit hari berikutnya -- persis seperti yang dilakukan orang di
--  meja depan dengan buku catatannya sejak sebelum ada aplikasi ini.
--
--  Sampai sekarang server menstempel tanggal_selesai dan tanggal_lunas
--  dengan tanggal kalender apa adanya. Akibatnya pekerjaan yang dituntaskan
--  jam 18.00 masuk ke laporan yang sudah dikirim tiga jam sebelumnya --
--  dan baru ketahuan saat angkanya tidak cocok dengan yang di pusat.
--
--  ---------------------------------------------------------------------
--  JAMNYA DISIMPAN DI PENGATURAN, BUKAN DITULIS DI SINI
--  ---------------------------------------------------------------------
--  Jam tutup bisa bergeser: bulan puasa, hari libur, atau sekadar
--  keputusan baru. Yang mengubahnya orang yang sedang berdiri di toko,
--  bukan yang bisa membuka SQL Editor. Ditanam sebagai angka di dalam
--  fungsi, perubahannya akan menunggu migrasi berikutnya -- dan selama
--  menunggu, angka laporannya salah setiap hari.
--
--  ---------------------------------------------------------------------
--  YANG TIDAK BERUBAH
--  ---------------------------------------------------------------------
--  tanggal_masuk tetap timestamptz apa adanya, jam aslinya utuh. Nota
--  yang tercetak harus menyebut jam unit itu benar-benar diterima, dan
--  pergeseran hari kerja adalah cara membacanya, bukan penggantian
--  faktanya. Aplikasi yang menggeser saat mengelompokkan.
--
--  Baris yang sudah ada tidak disentuh. Tanggalnya terlanjur distempel
--  dengan aturan lama, dan menggesernya sekarang akan memindahkan omset
--  yang laporannya sudah dikirim ke pusat.
--
--  Aman dijalankan ulang.
-- =====================================================================

-- ---------------------------------------------------------------------
--  1. JAMNYA
-- ---------------------------------------------------------------------
alter table store_settings
  add column if not exists tutup_jam smallint not null default 17;

do $ubah$
begin
  alter table store_settings drop constraint if exists tutup_jam_masuk_akal;
  alter table store_settings add constraint tutup_jam_masuk_akal
    check (tutup_jam between 1 and 24);
end
$ubah$;

comment on column store_settings.tutup_jam is
  'Jam laporan harian ditutup, 1-24 waktu Asia/Jakarta. Nota pada jam ini '
  'atau sesudahnya dihitung sebagai hari berikutnya. 24 berarti hari '
  'kalender biasa, tanpa pergeseran.';


-- ---------------------------------------------------------------------
--  2. MENGHITUNG HARI KERJANYA
-- ---------------------------------------------------------------------
--  Ditulis sekali di sini lalu dipakai kedua trigger. Aturan sehalus ini
--  yang disalin dua kali pasti berbeda suatu saat, dan bedanya baru
--  ketahuan sebagai satu nota yang hilang dari laporan.
create or replace function jam_tutup()
returns smallint
language sql stable security definer set search_path = public as $fn$
  select coalesce((select tutup_jam from store_settings where id = 1),
                  17::smallint);
$fn$;

--  Digeser maju sebanyak sisa hari sesudah jam tutup. Dengan tutup 17.00,
--  jam 16.59 + 7 jam masih hari yang sama; jam 17.00 + 7 jam sudah lewat
--  tengah malam. Batasnya menyertakan jam tutupnya sendiri, sama seperti
--  di aplikasi.
create or replace function hari_laporan(saat timestamptz default now())
returns date
language sql stable security definer set search_path = public as $fn$
  select ((saat at time zone 'Asia/Jakarta')
          + make_interval(hours => 24 - jam_tutup()))::date;
$fn$;

comment on function hari_laporan(timestamptz) is
  'Hari kerja yang menaungi sebuah saat. Hari di toko berganti pada '
  'store_settings.tutup_jam, bukan tengah malam.';


-- ---------------------------------------------------------------------
--  3. STEMPEL TANGGALNYA
-- ---------------------------------------------------------------------
--  Isinya sama persis seperti di migrasi 0020 -- termasuk pertanyaan ke
--  tabel metode_bayar, yang menentukan sebuah cara bayar berarti lunas
--  atau piutang -- kecuali cara menghitung harinya.
create or replace function sentuh_service_order()
returns trigger
language plpgsql security definer set search_path = public as $fn$
begin
  new.updated_at := now();

  -- Nota yang diambil dengan cara bayar yang bukan piutang berarti
  -- uangnya sudah diterima hari itu juga.
  if new.status = 'diambil'
     and new.cara_bayar is not null
     and new.tanggal_lunas is null
     and not coalesce(
       (select m.piutang from metode_bayar m where m.kode = new.cara_bayar),
       false
     )
  then
    new.tanggal_lunas := hari_laporan();
  end if;

  -- Tanggal selesai diisi sekali saja, saat pertama kali pekerjaannya
  -- dinyatakan rampung. Perubahan status berikutnya tidak menggesernya --
  -- kalau tidak, membuka kembali nota lama akan memindahkan omsetnya ke
  -- bulan berjalan.
  if new.status in ('selesai', 'diambil') and new.tanggal_selesai is null then
    new.tanggal_selesai := hari_laporan();
  end if;

  return new;
end;
$fn$;
