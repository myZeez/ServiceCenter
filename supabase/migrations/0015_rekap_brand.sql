-- =====================================================================
--  Migrasi 0015 : rekap bulanan dari brand
--
--  Fee tidak lagi satu angka per brand. Tiap bulan brand mengirim rekap
--  unit yang sudah tuntas beserta biaya yang mereka bayar, dan angkanya
--  berbeda-beda antar unit -- tergantung part dan pekerjaannya, bukan
--  tergantung mereknya saja. Pencocokannya memakai nomor perbaikan (RMA).
--
--  Karena itu nilai sebuah unit sekarang punya dua lapis:
--
--    1. fee brand di brand_fees  -- nilai awal, supaya tidak perlu
--                                   mengetik ulang angka yang biasanya sama
--    2. claim_settlements.fee    -- angka sebenarnya dari surat brand,
--                                   diisi hanya untuk unit yang berbeda
--
--  Lapis pertama sengaja dipertahankan. Membuang begitu saja berarti
--  seluruh klaim yang sudah dibayarkan kehilangan nilainya, dan rekap
--  kuartal yang sudah lewat berubah jadi nol.
--
--  Aman dijalankan ulang.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. KAPAN SEBUAH KLAIM DITUTUP
--
--    Brand mengirim rekapnya per bulan, jadi harus ada tanggal yang
--    menentukan sebuah unit masuk bulan yang mana. Tanggal klaim tidak
--    bisa dipakai: itu tanggal unitnya datang, dan unit yang masuk akhir
--    Maret sering baru tuntas di April.
--
--    Bentuknya sengaja sama persis dengan tanggal_selesai pada nota servis
--    (migrasi 0009) -- persoalannya sama, dan dua penyelesaian berbeda
--    untuk persoalan yang sama hanya akan membingungkan yang membacanya.
-- ---------------------------------------------------------------------
alter table claims add column if not exists tanggal_close date;

create index if not exists claims_close on claims (tanggal_close);

-- Klaim lama yang sudah selesai tetapi belum punya tanggal: diisi dari
-- waktu perubahan terakhirnya. Perkiraan, tetapi lebih baik daripada
-- hilang sama sekali dari rekap.
update claims
set tanggal_close = (updated_at at time zone 'Asia/Jakarta')::date
where tanggal_close is null
  and status = 'close';


-- Diisi sekali saja, saat pertama kali klaimnya dinyatakan selesai.
-- Perubahan status berikutnya tidak menggesernya: kalau tidak, membuka
-- kembali klaim lama akan memindahkannya ke rekap bulan berjalan --
-- padahal brand sudah membayarnya di bulan yang lain.
create or replace function claims_stempel_close()
returns trigger
language plpgsql security definer set search_path = public as $fn$
begin
  if new.status = 'close' and new.tanggal_close is null then
    new.tanggal_close := (now() at time zone 'Asia/Jakarta')::date;
  end if;
  return new;
end;
$fn$;

-- Namanya harus urut sesudah trg_claims_guard. Trigger dengan waktu yang
-- sama dijalankan menurut abjad, dan penolakan harus terjadi lebih dulu,
-- sebelum ada kolom yang diisi otomatis.
drop trigger if exists trg_claims_stempel on claims;
create trigger trg_claims_stempel
  before insert or update on claims
  for each row execute function claims_stempel_close();


-- Tanggal tutup menentukan bulan rekap, dan bulan rekap menentukan kapan
-- sebuah unit dibayarkan. Karena itu ia ikut dijaga seperti kolom uang
-- yang lain: teknisi tidak bisa menggesernya.
--
-- Sisa isi fungsi ini sama persis dengan aslinya di migrasi 0001.
create or replace function claims_guard_update()
returns trigger
language plpgsql security definer set search_path = public as $fn$
begin
  if not is_admin() then
    if (new.tanggal, new.brand_id, new.nama_pelanggan, new.telp, new.sn,
        new.keluhan, new.no_perbaikan, new.status, new.catatan,
        new.created_by, new.tanggal_close)
       is distinct from
       (old.tanggal, old.brand_id, old.nama_pelanggan, old.telp, old.sn,
        old.keluhan, old.no_perbaikan, old.status, old.catatan,
        old.created_by, old.tanggal_close)
    then
      raise exception 'Teknisi hanya boleh mengubah kolom teknisi.';
    end if;
  end if;

  new.updated_at := now();
  return new;
end;
$fn$;


-- ---------------------------------------------------------------------
-- 2. HASIL PENCOCOKAN DENGAN SURAT BRAND
--
--    Satu baris per unit, dan hanya untuk unit yang memang perlu dicatat:
--    yang angkanya berbeda dari nilai awal, atau yang sudah dicocokkan.
--    Unit yang nilainya persis sama dengan fee brand tidak perlu baris
--    sama sekali.
--
--    fee boleh kosong. Kosong berarti "pakai nilai awal dari brand_fees" --
--    berbeda dari nol, yang berarti brand memang tidak membayar unit itu.
-- ---------------------------------------------------------------------
create table if not exists claim_settlements (
  claim_id   uuid          primary key references claims(id) on delete cascade,
  fee        numeric(12,2) check (fee >= 0),
  cocok      boolean       not null default false,
  catatan    text,
  updated_at timestamptz   not null default now(),
  updated_by uuid          references profiles(id) default auth.uid()
);

create or replace function sentuh_claim_settlement()
returns trigger
language plpgsql security definer set search_path = public as $fn$
begin
  new.updated_at := now();
  new.updated_by := auth.uid();
  return new;
end;
$fn$;

drop trigger if exists trg_sentuh_settlement on claim_settlements;
create trigger trg_sentuh_settlement
  before insert or update on claim_settlements
  for each row execute function sentuh_claim_settlement();


-- ---------------------------------------------------------------------
-- 3. AKSES
--
--    Isinya angka rupiah yang dibayar brand, jadi aturannya sama dengan
--    brand_fees: hanya admin. Teknisi menarik nol baris, bukan sekadar
--    tidak melihatnya di layar.
-- ---------------------------------------------------------------------
alter table claim_settlements enable row level security;

drop policy if exists settlements_admin on claim_settlements;
create policy settlements_admin on claim_settlements for all to authenticated
  using (is_admin()) with check (is_admin());


-- ---------------------------------------------------------------------
-- 4. REALTIME
--
--    Dua langkah, dan yang kedua yang paling mudah terlewat. Tanpa
--    replica identity full, kabar penghapusan dibuang diam-diam dan
--    barisnya tetap tampil di layar orang lain. Penjelasan lengkapnya
--    ada di migrasi 0012.
-- ---------------------------------------------------------------------
do $realtime$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'claim_settlements'
  ) then
    alter publication supabase_realtime add table public.claim_settlements;
  end if;
end
$realtime$;

alter table claim_settlements replica identity full;
