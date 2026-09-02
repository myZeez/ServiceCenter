-- =====================================================================
--  Migrasi 0005 : administrasi servis
--
--  Modul ini mencatat layanan ke PELANGGAN: nota masuk, biaya, pelunasan,
--  dan pengambilan unit. Berbeda dari klaim garansi yang sudah ada, yang
--  mencatat pengajuan ke BRAND: nomor RMA, part, dan bagi hasil.
--
--  Satu unit yang masuk selalu menghasilkan satu nota. Kalau unit itu
--  bergaransi, notanya menunjuk ke klaim garansinya -- jadi data pelanggan
--  dan nomor seri cukup diketik sekali.
--
--  Aman dijalankan ulang.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. TIPE
-- ---------------------------------------------------------------------
do $$ begin
  create type service_status as enum (
    'masuk', 'dikerjakan', 'tunggu_part', 'selesai', 'diambil', 'batal'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type cara_bayar as enum ('cash', 'piutang');
exception when duplicate_object then null; end $$;

do $$ begin
  create type status_kirim as enum ('ship', 'received');
exception when duplicate_object then null; end $$;

do $$ begin
  create type jenis_kirim as enum ('garansi', 'non_garansi', 'cid');
exception when duplicate_object then null; end $$;


-- ---------------------------------------------------------------------
-- 2. NOTA SERVIS
-- ---------------------------------------------------------------------
create table if not exists service_orders (
  id            uuid primary key default gen_random_uuid(),

  -- Diisi otomatis oleh trigger di bagian 4.
  no_nota       text        not null unique,

  tanggal_masuk timestamptz not null default now(),
  estimasi_selesai date,

  customer_nama text        not null,
  customer_telp text,

  -- Admin yang menerima unit di meja depan. Berbeda dari teknisi yang
  -- mengerjakannya, dan berbeda pula dari created_by bila nota disunting
  -- orang lain belakangan.
  operator_id   uuid references profiles(id),

  barang_nama   text        not null,
  barang_type   text,
  barang_sn     text,
  kelengkapan   text,

  keluhan       text,
  teknisi_id    uuid references profiles(id),

  -- Apa yang benar-benar dikerjakan; terisi setelah servis selesai.
  perbaikan     text,

  garansi       boolean     not null default false,
  claim_id      uuid references claims(id) on delete set null,

  status        service_status not null default 'masuk',

  biaya         numeric(12,2) not null default 0 check (biaya >= 0),
  cara_bayar    cara_bayar,
  tanggal_lunas date,

  keterangan    text,

  created_by    uuid        not null references profiles(id) default auth.uid(),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),

  -- Piutang yang sudah ditandai lunas tanpa tanggal akan hilang dari
  -- laporan pelunasan, jadi keduanya harus konsisten.
  constraint lunas_perlu_cara_bayar
    check (tanggal_lunas is null or cara_bayar is not null)
);

create index if not exists so_tanggal    on service_orders (tanggal_masuk desc);
create index if not exists so_status     on service_orders (status);
create index if not exists so_teknisi    on service_orders (teknisi_id);
create index if not exists so_lunas      on service_orders (tanggal_lunas);
create index if not exists so_sn         on service_orders (barang_sn);
create index if not exists so_claim      on service_orders (claim_id);


-- ---------------------------------------------------------------------
-- 3. PENGIRIMAN ANTAR CABANG
--
--    Cabang disimpan sebagai teks, bukan tabel tersendiri: sistem ini
--    hanya dipakai di sini, dan cabang lain tidak ikut mencatat di dalamnya.
-- ---------------------------------------------------------------------
create table if not exists shipments (
  id             uuid primary key default gen_random_uuid(),
  tanggal_kirim  date        not null,
  dari_cabang    text        not null,
  ke_cabang      text        not null,
  user_nama      text,

  barang_nama    text        not null,
  serial_number  text,
  keluhan        text,
  kelengkapan    text,

  status         status_kirim not null default 'ship',
  tanggal_kembali date,
  keterangan     jenis_kirim,

  created_by     uuid        not null references profiles(id) default auth.uid(),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create index if not exists kirim_tanggal on shipments (tanggal_kirim desc);
create index if not exists kirim_status  on shipments (status);


-- ---------------------------------------------------------------------
-- 4. PENOMORAN NOTA
--
--    Format YYMM-NNN, mengulang dari 001 tiap bulan.
--
--    Nomor ditetapkan server, bukan perangkat. Dua admin yang menyimpan
--    bersamaan harus mustahil mendapat nomor sama -- nota yang sudah
--    tercetak dengan nomor kembar tidak bisa diperbaiki belakangan.
-- ---------------------------------------------------------------------
create or replace function buat_no_nota()
returns text
language plpgsql volatile security definer set search_path = public as $fn$
declare
  awalan text := to_char(now() at time zone 'Asia/Jakarta', 'YYMM');
  urut   integer;
begin
  -- Kunci tingkat transaksi: penyimpanan bersamaan akan mengantre, bukan
  -- saling menimpa.
  perform pg_advisory_xact_lock(hashtext('no_nota_' || awalan));

  select coalesce(max(nullif(split_part(no_nota, '-', 2), '')::integer), 0) + 1
    into urut
  from service_orders
  where no_nota like awalan || '-%';

  return awalan || '-' || lpad(urut::text, 3, '0');
end;
$fn$;

create or replace function isi_no_nota()
returns trigger
language plpgsql security definer set search_path = public as $fn$
begin
  if new.no_nota is null or new.no_nota = '' then
    new.no_nota := buat_no_nota();
  end if;
  return new;
end;
$fn$;

drop trigger if exists trg_no_nota on service_orders;
create trigger trg_no_nota
  before insert on service_orders
  for each row execute function isi_no_nota();

-- Kolom wajib diisi, tetapi trigger yang mengisinya. Nilai sementara ini
-- membuat aplikasi tidak perlu mengirim apa pun untuk no_nota.
alter table service_orders alter column no_nota drop not null;


-- ---------------------------------------------------------------------
-- 5. JEJAK PERUBAHAN
-- ---------------------------------------------------------------------
create or replace function sentuh_service_order()
returns trigger
language plpgsql security definer set search_path = public as $fn$
begin
  new.updated_at := now();

  -- Nota yang berpindah ke 'diambil' tanpa dibayar tunai berarti piutang;
  -- tanggal lunasnya diisi belakangan saat pelanggan melunasi.
  if new.status = 'diambil' and new.cara_bayar = 'cash'
     and new.tanggal_lunas is null then
    new.tanggal_lunas := (now() at time zone 'Asia/Jakarta')::date;
  end if;

  return new;
end;
$fn$;

drop trigger if exists trg_so_touch on service_orders;
create trigger trg_so_touch
  before update on service_orders
  for each row execute function sentuh_service_order();

create or replace function sentuh_shipment()
returns trigger
language plpgsql security definer set search_path = public as $fn$
begin
  new.updated_at := now();
  return new;
end;
$fn$;

drop trigger if exists trg_kirim_touch on shipments;
create trigger trg_kirim_touch
  before update on shipments
  for each row execute function sentuh_shipment();


-- ---------------------------------------------------------------------
-- 6. AKSES
--
--    Nota memuat biaya dan piutang, jadi hanya admin yang boleh membacanya.
--    Teknisi bekerja dari daftar klaim, bukan dari nota.
-- ---------------------------------------------------------------------
alter table service_orders enable row level security;
alter table shipments      enable row level security;

drop policy if exists so_admin on service_orders;
create policy so_admin on service_orders for all to authenticated
  using (is_admin()) with check (is_admin());

drop policy if exists kirim_admin on shipments;
create policy kirim_admin on shipments for all to authenticated
  using (is_admin()) with check (is_admin());
