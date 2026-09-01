-- =====================================================================
--  SERVICE CLAIM GARANSI - CELLCOM PLK
--  Migrasi 0001 : skema inti
--  Jalankan di Supabase Dashboard > SQL Editor
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. TIPE
-- ---------------------------------------------------------------------
create type claim_status as enum ('open', 'proses', 'tunggu_part', 'close', 'batal');
create type user_role    as enum ('admin', 'teknisi');


-- ---------------------------------------------------------------------
-- 2. MASTER DATA
--    8 tab brand di sheet lama jadi 1 tabel. Inilah yang bikin rekap
--    lintas-brand mungkin tanpa copy-paste manual.
-- ---------------------------------------------------------------------
create table brands (
  id    smallint generated always as identity primary key,
  nama  text     not null unique,
  aktif boolean  not null default true
);

create table part_types (
  id    smallint generated always as identity primary key,
  kode  text     not null unique,
  nama  text     not null,
  aktif boolean  not null default true
);

-- Profil user, 1:1 dengan tabel auth.users bawaan Supabase.
create table profiles (
  id         uuid primary key references auth.users(id) on delete cascade,
  nama       text        not null,
  role       user_role   not null default 'teknisi',
  aktif      boolean     not null default true,
  created_at timestamptz not null default now()
);


-- ---------------------------------------------------------------------
-- 3. TABEL UTAMA
--    id sengaja UUID (bukan angka urut) supaya app bisa membuat record
--    saat offline tanpa menunggu server memberi nomor.
-- ---------------------------------------------------------------------
create table claims (
  id             uuid primary key default gen_random_uuid(),

  -- Diisi app memakai jam lokal saat teknisi input, BUKAN saat sinkron.
  -- Kalau tidak, klaim yang diinput offline hari Senin akan tercatat
  -- tanggal Rabu waktu HP-nya baru dapat sinyal.
  tanggal        timestamptz  not null default now(),

  brand_id       smallint     not null references brands(id),
  nama_pelanggan text         not null,
  telp           text,
  sn             text         not null,
  teknisi_id     uuid         references profiles(id),
  keluhan        text,
  no_perbaikan   text         unique,
  status         claim_status not null default 'open',
  catatan        text,

  created_by     uuid         not null references profiles(id) default auth.uid(),
  created_at     timestamptz  not null default now(),
  updated_at     timestamptz  not null default now()
);

create index on claims (brand_id);
create index on claims (teknisi_id);
create index on claims (tanggal);
create index on claims (sn);


-- ---------------------------------------------------------------------
-- 4. PART YANG DIKLAIM
--    Tabel terpisah, bukan satu kolom. Alasannya ada di sheet lama
--    sendiri: baris 17 isinya "MB/SUB BOARD" - dua part dalam satu
--    klaim. Dan tiap part punya SN bad part sendiri-sendiri.
-- ---------------------------------------------------------------------
create table claim_parts (
  id           uuid        primary key default gen_random_uuid(),
  claim_id     uuid        not null references claims(id) on delete cascade,
  part_type_id smallint    not null references part_types(id),
  sn_bad_part  text,
  created_at   timestamptz not null default now()
);

create index on claim_parts (claim_id);


-- ---------------------------------------------------------------------
-- 5. JEJAK PERUBAHAN
--    Wajib ada: nama teknisi menentukan bagi hasil, jadi setiap
--    perpindahan harus punya bukti siapa yang mengubah dan kapan.
-- ---------------------------------------------------------------------
create table claim_audit (
  id          bigint generated always as identity primary key,
  claim_id    uuid   not null references claims(id) on delete cascade,
  kolom       text   not null,
  nilai_lama  text,
  nilai_baru  text,
  diubah_oleh uuid   not null references profiles(id),
  diubah_pada timestamptz not null default now()
);

create index on claim_audit (claim_id);
create index on claim_audit (diubah_pada);


-- ---------------------------------------------------------------------
-- 6. HELPER
-- ---------------------------------------------------------------------
create or replace function is_admin()
returns boolean
language sql stable security definer set search_path = public as $fn$
  select exists (
    select 1 from profiles
    where id = auth.uid() and role = 'admin' and aktif
  );
$fn$;


-- ---------------------------------------------------------------------
-- 7. ATURAN AKSES (Row Level Security)
--    admin   : akses penuh
--    teknisi : lihat semua, input baru, tapi HANYA boleh mengubah
--              kolom teknisi_id
-- ---------------------------------------------------------------------
alter table claims      enable row level security;
alter table claim_parts enable row level security;
alter table claim_audit enable row level security;
alter table profiles    enable row level security;
alter table brands      enable row level security;
alter table part_types  enable row level security;

-- Semua user yang login boleh melihat seluruh klaim.
create policy claims_select on claims
  for select to authenticated using (true);

create policy claims_insert on claims
  for insert to authenticated with check (true);

-- Batasan per-kolom ditegakkan oleh trigger di bagian 8,
-- karena RLS Postgres bekerja per-baris, bukan per-kolom.
create policy claims_update on claims
  for update to authenticated using (true) with check (true);

create policy claims_delete on claims
  for delete to authenticated using (is_admin());

-- Part: teknisi boleh menambah saat input; hanya admin yang boleh ubah/hapus.
create policy cp_select on claim_parts for select to authenticated using (true);
create policy cp_insert on claim_parts for insert to authenticated with check (true);
create policy cp_update on claim_parts for update to authenticated using (is_admin());
create policy cp_delete on claim_parts for delete to authenticated using (is_admin());

-- Audit: boleh dibaca, tidak boleh disentuh siapa pun lewat API.
-- Pengisian hanya lewat trigger (security definer).
create policy audit_select on claim_audit for select to authenticated using (true);

-- Master data: semua boleh baca, hanya admin yang boleh ubah.
create policy brands_select on brands for select to authenticated using (true);
create policy brands_write  on brands for all    to authenticated
  using (is_admin()) with check (is_admin());

create policy parts_select on part_types for select to authenticated using (true);
create policy parts_write  on part_types for all  to authenticated
  using (is_admin()) with check (is_admin());

create policy profiles_select on profiles for select to authenticated using (true);
create policy profiles_write  on profiles for all  to authenticated
  using (is_admin()) with check (is_admin());


-- ---------------------------------------------------------------------
-- 8. TRIGGER
-- ---------------------------------------------------------------------

-- 8a. Teknisi hanya boleh menyentuh kolom teknisi_id.
--     Ditegakkan di server, jadi tidak bisa dilewati walaupun seseorang
--     memanggil API-nya langsung tanpa lewat aplikasi.
create or replace function claims_guard_update()
returns trigger
language plpgsql security definer set search_path = public as $fn$
begin
  if not is_admin() then
    if (new.tanggal, new.brand_id, new.nama_pelanggan, new.telp, new.sn,
        new.keluhan, new.no_perbaikan, new.status, new.catatan, new.created_by)
       is distinct from
       (old.tanggal, old.brand_id, old.nama_pelanggan, old.telp, old.sn,
        old.keluhan, old.no_perbaikan, old.status, old.catatan, old.created_by)
    then
      raise exception 'Teknisi hanya boleh mengubah kolom teknisi.';
    end if;
  end if;

  new.updated_at := now();
  return new;
end;
$fn$;

create trigger trg_claims_guard
  before update on claims
  for each row execute function claims_guard_update();


-- 8b. Catat setiap perpindahan teknisi.
create or replace function claims_log_teknisi()
returns trigger
language plpgsql security definer set search_path = public as $fn$
begin
  if new.teknisi_id is distinct from old.teknisi_id then
    insert into claim_audit (claim_id, kolom, nilai_lama, nilai_baru, diubah_oleh)
    values (
      new.id,
      'teknisi',
      (select nama from profiles where id = old.teknisi_id),
      (select nama from profiles where id = new.teknisi_id),
      auth.uid()
    );
  end if;
  return null;
end;
$fn$;

create trigger trg_claims_audit
  after update on claims
  for each row execute function claims_log_teknisi();


-- ---------------------------------------------------------------------
-- 9. REKAP
--    Inilah yang di sheet lama butuh rumus di file Excel terpisah.
-- ---------------------------------------------------------------------

-- Berapa unit masuk tiap brand, per kuartal.
create view v_rekap_brand_kuartal as
select
  b.nama                                 as brand,
  date_trunc('quarter', c.tanggal)::date as kuartal,
  count(*)                               as jumlah_klaim
from claims c
join brands b on b.id = c.brand_id
group by b.nama, date_trunc('quarter', c.tanggal);

-- Tiap teknisi mengerjakan berapa unit di tiap brand, per kuartal.
create view v_rekap_teknisi_brand as
select
  coalesce(p.nama, '(belum ditugaskan)') as teknisi,
  b.nama                                 as brand,
  date_trunc('quarter', c.tanggal)::date as kuartal,
  count(*)                               as jumlah_dikerjakan
from claims c
join brands b        on b.id = c.brand_id
left join profiles p on p.id = c.teknisi_id
group by p.nama, b.nama, date_trunc('quarter', c.tanggal);

-- Riwayat perpindahan teknisi, siap dibaca admin.
create view v_riwayat_pindah_teknisi as
select
  a.diubah_pada,
  c.no_perbaikan,
  c.sn,
  b.nama       as brand,
  a.nilai_lama as dari_teknisi,
  a.nilai_baru as ke_teknisi,
  pe.nama      as diubah_oleh
from claim_audit a
join claims   c  on c.id  = a.claim_id
join brands   b  on b.id  = c.brand_id
join profiles pe on pe.id = a.diubah_oleh
where a.kolom = 'teknisi'
order by a.diubah_pada desc;


-- ---------------------------------------------------------------------
-- 10. DATA AWAL
-- ---------------------------------------------------------------------
insert into brands (nama) values
  ('ASUS'), ('ACER'), ('AXIOO'), ('LENOVO'),
  ('HP'), ('MSI'), ('CANON'), ('DAC');

insert into part_types (kode, nama) values
  ('MB',        'Mainboard'),
  ('LCD',       'LCD Panel'),
  ('KB',        'Keyboard'),
  ('BT',        'Baterai'),
  ('ADP',       'Adaptor'),
  ('PSU',       'Power Supply'),
  ('SUB_BOARD', 'Sub Board');
