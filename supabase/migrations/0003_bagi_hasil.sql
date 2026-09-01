-- =====================================================================
--  Migrasi 0003 : fee brand dan aturan bagi hasil
--
--  Berkas ini hanya menyimpan DATA-nya. Perhitungannya sendiri ada di
--  aplikasi (lib/core/revenue/revenue_calculator.dart), bukan di sini.
--
--  Alasannya dua. Pertama, seluruh aplikasi bekerja dari data di perangkat
--  supaya tetap jalan tanpa koneksi, dan halaman pendapatan tidak boleh
--  jadi satu-satunya pengecualian. Kedua, rumus yang menentukan bayaran
--  orang sebaiknya cuma punya satu implementasi -- dua salinan pasti
--  berbeda suatu saat, dan selisihnya baru ketahuan setelah dibayarkan.
--
--  Aman dijalankan ulang.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. FEE PER BRAND
--
--    Memakai tanggal berlaku, bukan satu kolom fee di tabel brands.
--    Kalau fee lama ditimpa, rekap kuartal yang sudah lewat ikut berubah
--    angkanya -- dan pembagian yang terlanjur dibayarkan tidak lagi cocok
--    dengan laporannya.
-- ---------------------------------------------------------------------
create table if not exists brand_fees (
  id           bigint generated always as identity primary key,
  brand_id     smallint      not null references brands(id) on delete cascade,
  fee          numeric(12,2) not null check (fee >= 0),
  berlaku_dari date          not null,
  catatan      text,
  created_at   timestamptz   not null default now(),

  unique (brand_id, berlaku_dari)
);

create index if not exists brand_fees_lookup
  on brand_fees (brand_id, berlaku_dari desc);


-- ---------------------------------------------------------------------
-- 2. ATURAN PEMBAGIAN
--
--    Satu baris saja. Kunci id = 1 memastikan tidak ada aturan kedua yang
--    diam-diam ikut terpakai.
-- ---------------------------------------------------------------------
create table if not exists revenue_settings (
  id             smallint     primary key default 1 check (id = 1),
  persen_toko    numeric(5,2) not null default 30,
  persen_admin   numeric(5,2) not null default 10,
  persen_teknisi numeric(5,2) not null default 60,

  -- per_unit : jatah teknisi dibagi menurut nilai yang dihasilkan
  -- rata     : dibagi sama besar antar teknisi yang bekerja di periode itu
  -- manual   : memakai persentase tetap di tabel technician_shares
  metode_teknisi text not null default 'per_unit'
    check (metode_teknisi in ('per_unit', 'rata', 'manual')),

  updated_at timestamptz not null default now(),
  updated_by uuid references profiles(id),

  -- Menjaga agar totalnya tidak pernah meleset dari 100%.
  constraint total_100
    check (persen_toko + persen_admin + persen_teknisi = 100)
);

insert into revenue_settings (id) values (1) on conflict (id) do nothing;

-- Persentase tetap per teknisi. Hanya dipakai saat metode 'manual'.
create table if not exists technician_shares (
  profile_id uuid         primary key references profiles(id) on delete cascade,
  persen     numeric(5,2) not null check (persen >= 0 and persen <= 100),
  updated_at timestamptz  not null default now()
);


-- ---------------------------------------------------------------------
-- 3. Membuang perhitungan versi SQL bila pernah terpasang.
--
--    Sempat ada di rancangan awal, lalu dipindahkan ke aplikasi. Dibiarkan
--    hidup berdampingan justru berbahaya: dua rumus untuk hal yang sama.
-- ---------------------------------------------------------------------
drop function if exists ringkasan_pendapatan(date, date);
drop function if exists pendapatan_teknisi(date, date);
drop function if exists pendapatan_brand(date, date);
drop function if exists fee_berlaku(smallint, date);
drop view     if exists v_nilai_klaim;


-- ---------------------------------------------------------------------
-- 4. AKSES
--
--    Angka fee dan aturan pembagian hanya untuk admin. Teknisi menarik nol
--    baris saat sinkron, jadi angka ini tidak pernah sampai ke perangkat
--    mereka -- ditegakkan di sini, bukan disembunyikan di aplikasi.
-- ---------------------------------------------------------------------
alter table brand_fees        enable row level security;
alter table revenue_settings  enable row level security;
alter table technician_shares enable row level security;

drop policy if exists fees_admin on brand_fees;
create policy fees_admin on brand_fees for all to authenticated
  using (is_admin()) with check (is_admin());

drop policy if exists settings_admin on revenue_settings;
create policy settings_admin on revenue_settings for all to authenticated
  using (is_admin()) with check (is_admin());

drop policy if exists shares_admin on technician_shares;
create policy shares_admin on technician_shares for all to authenticated
  using (is_admin()) with check (is_admin());
