-- =====================================================================
--  Migrasi 0009 : omset jasa servis
--
--  Ini kantong kedua, terpisah dari bagi hasil garansi. Yang garansi
--  sumbernya fee dari brand; yang ini jasa yang dibayar pelanggan. Aturan
--  dan periodenya berbeda, jadi perhitungannya tidak boleh dicampur.
--
--  Aman dijalankan ulang.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. TANGGAL SELESAI
--
--    Omset dihitung dari kapan pekerjaan SELESAI, bukan kapan unit masuk
--    atau kapan pelanggan melunasi:
--
--    - unit yang masuk 30 September dan selesai 2 Oktober adalah omset
--      Oktober, karena di bulan itulah pekerjaannya dilakukan;
--    - pelanggan yang menunda pembayaran bukan salah teknisi, jadi piutang
--      tetap dihitung sebagai omset.
-- ---------------------------------------------------------------------
alter table service_orders
  add column if not exists tanggal_selesai date;

create index if not exists so_selesai on service_orders (tanggal_selesai);

-- Baris lama yang sudah selesai tetapi belum punya tanggal: diisi dari
-- waktu perubahan terakhirnya. Perkiraan, tetapi lebih baik daripada
-- hilang sama sekali dari laporan omset.
update service_orders
set tanggal_selesai = (updated_at at time zone 'Asia/Jakarta')::date
where tanggal_selesai is null
  and status in ('selesai', 'diambil');


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

  -- Tanggal selesai diisi sekali saja, saat pertama kali pekerjaannya
  -- dinyatakan rampung. Perubahan status berikutnya tidak menggesernya --
  -- kalau tidak, membuka kembali nota lama akan memindahkan omsetnya ke
  -- bulan berjalan.
  if new.status in ('selesai', 'diambil') and new.tanggal_selesai is null then
    new.tanggal_selesai := (now() at time zone 'Asia/Jakarta')::date;
  end if;

  return new;
end;
$fn$;


-- ---------------------------------------------------------------------
-- 2. ATURAN OMSET
-- ---------------------------------------------------------------------
create table if not exists service_settings (
  id                  smallint primary key default 1 check (id = 1),

  -- Target produksi bulanan tiap teknisi, dalam rupiah. Bukan target gaji:
  -- yang diukur adalah jasa yang dihasilkannya.
  target_omset        numeric(12,2) not null default 4000000
                        check (target_omset >= 0),

  -- Imbalan admin untuk tiap nota yang keluar, berapa pun biaya jasanya.
  fee_admin_per_nota  numeric(12,2) not null default 0
                        check (fee_admin_per_nota >= 0),

  updated_at          timestamptz not null default now(),
  updated_by          uuid references profiles(id)
);

insert into service_settings (id) values (1) on conflict (id) do nothing;

alter table service_settings enable row level security;

drop policy if exists servis_setting_admin on service_settings;
create policy servis_setting_admin on service_settings for all to authenticated
  using (is_admin()) with check (is_admin());
