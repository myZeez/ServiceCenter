-- =====================================================================
--  Migrasi 0004 : pembagian dihitung per brand
--
--  Tiap brand membayar fee berbeda dan ditangani susunan tim yang berbeda.
--  Persentase tunggal untuk semua brand tidak bisa menggambarkan itu:
--  seseorang bisa berporsi besar di satu brand dan kecil di brand lain,
--  termasuk karena pekerjaan pendukung seperti input klaim dan permintaan
--  part -- yang tidak muncul sebagai unit atas namanya.
--
--  Aman dijalankan ulang.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. ATURAN PEMBAGIAN KHUSUS PER BRAND
--
--    Opsional. Brand yang tidak punya baris di sini memakai aturan umum
--    di revenue_settings.
-- ---------------------------------------------------------------------
create table if not exists brand_revenue_rules (
  brand_id       smallint     primary key references brands(id) on delete cascade,
  persen_toko    numeric(5,2) not null,
  persen_admin   numeric(5,2) not null,
  persen_teknisi numeric(5,2) not null,
  updated_at     timestamptz  not null default now(),

  constraint brand_total_100
    check (persen_toko + persen_admin + persen_teknisi = 100)
);


-- ---------------------------------------------------------------------
-- 2. PORSI TEKNISI PER BRAND
--
--    Menggantikan technician_shares yang berlaku global.
-- ---------------------------------------------------------------------
create table if not exists brand_technician_shares (
  brand_id   smallint     not null references brands(id) on delete cascade,
  profile_id uuid         not null references profiles(id) on delete cascade,
  persen     numeric(5,2) not null check (persen >= 0 and persen <= 100),
  updated_at timestamptz  not null default now(),

  primary key (brand_id, profile_id)
);

create index if not exists brand_shares_lookup
  on brand_technician_shares (brand_id);

-- Pindahkan pengaturan lama, kalau ada: persentase global disalin ke setiap
-- brand sebagai titik awal, bukan dibuang begitu saja.
do $migrasi$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'technician_shares'
  ) then
    insert into brand_technician_shares (brand_id, profile_id, persen)
    select b.id, t.profile_id, t.persen
    from technician_shares t
    cross join brands b
    on conflict (brand_id, profile_id) do nothing;

    drop table technician_shares;
  end if;
end;
$migrasi$;


-- ---------------------------------------------------------------------
-- 3. AKSES
-- ---------------------------------------------------------------------
alter table brand_revenue_rules      enable row level security;
alter table brand_technician_shares  enable row level security;

drop policy if exists brand_rules_admin on brand_revenue_rules;
create policy brand_rules_admin on brand_revenue_rules for all to authenticated
  using (is_admin()) with check (is_admin());

drop policy if exists brand_shares_admin on brand_technician_shares;
create policy brand_shares_admin on brand_technician_shares
  for all to authenticated
  using (is_admin()) with check (is_admin());
