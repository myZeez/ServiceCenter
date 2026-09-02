-- =====================================================================
--  Migrasi 0008 : master pelanggan
--
--  Pelanggan yang sering datang tidak perlu diketik ulang, dan riwayat
--  servisnya bisa ditelusuri lewat satu kode.
--
--  Nota tetap menyimpan salinan nama dan telepon apa adanya. Nota yang
--  sudah tercetak harus tetap cocok dengan kertasnya walau nomor telepon
--  pelanggannya berubah setahun kemudian -- karena itu tautannya lemah:
--  customer_id boleh kosong, dan menghapus pelanggan tidak menghapus
--  notanya.
--
--  Aman dijalankan ulang.
-- =====================================================================

create sequence if not exists kode_pelanggan_seq start 1;

create table if not exists customers (
  id         uuid primary key default gen_random_uuid(),
  kode       text        not null unique,
  nama       text        not null,
  telp       text,
  alamat     text,
  catatan    text,
  created_by uuid        references profiles(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Pencarian dilakukan atas nama dan nomor telepon sekaligus: operator
-- membedakan dua orang bernama sama dari nomornya.
create index if not exists pelanggan_nama on customers (lower(nama));
create index if not exists pelanggan_telp on customers (telp);


create or replace function isi_kode_pelanggan()
returns trigger
language plpgsql security definer set search_path = public as $fn$
begin
  if new.kode is null or new.kode = '' then
    new.kode := 'PLG' || lpad(nextval('kode_pelanggan_seq')::text, 4, '0');
  end if;
  return new;
end;
$fn$;

drop trigger if exists trg_kode_pelanggan on customers;
create trigger trg_kode_pelanggan
  before insert on customers
  for each row execute function isi_kode_pelanggan();

alter table customers alter column kode drop not null;

create or replace function sentuh_customer()
returns trigger
language plpgsql security definer set search_path = public as $fn$
begin
  new.updated_at := now();
  return new;
end;
$fn$;

drop trigger if exists trg_customer_touch on customers;
create trigger trg_customer_touch
  before update on customers
  for each row execute function sentuh_customer();


-- Tautan dari nota. Sengaja SET NULL, bukan CASCADE: menghapus data
-- pelanggan tidak boleh ikut menghapus riwayat notanya.
alter table service_orders
  add column if not exists customer_id uuid
  references customers(id) on delete set null;

create index if not exists so_customer on service_orders (customer_id);


alter table customers enable row level security;

drop policy if exists pelanggan_admin on customers;
create policy pelanggan_admin on customers for all to authenticated
  using (is_admin()) with check (is_admin());
