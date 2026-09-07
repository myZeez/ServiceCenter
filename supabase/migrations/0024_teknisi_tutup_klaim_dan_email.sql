-- =====================================================================
--  Migrasi 0024 : teknisi menutup klaim sendiri, dan email pelanggan
--
--  Dua hal yang selama ini hilang dari sisi garansi.
--
--  ---------------------------------------------------------------------
--  1. TEKNISI BELUM BISA MENUTUP KLAIMNYA SENDIRI
--  ---------------------------------------------------------------------
--  Sejak 0014 teknisi boleh menutup pekerjaan dari nota servis, dan
--  0016 menyalurkan perubahan itu ke klaimnya. Tetapi klaim yang TIDAK
--  punya nota -- unit stok toko, kiriman cabang, walk-in murni garansi --
--  tidak punya jalur itu sama sekali. Statusnya hanya bisa digerakkan
--  admin, padahal yang tahu kapan unitnya rampung adalah teknisinya.
--
--  Penjaga kolom klaim dilonggarkan: status dan catatan sekarang milik
--  teknisi juga, sejalan dengan nota servis. Yang tetap tertutup adalah
--  identitas unit dan pelanggan, brand, tanggal masuk, nomor RMA, dan
--  tanggal tutup -- yang terakhir karena ia menentukan sebuah unit masuk
--  Rekap Brand bulan yang mana, dan itu urusan uang.
--
--  Part yang diklaim (claim_parts) sudah boleh ditambah teknisi sejak
--  0002 (cp_insert); mengubah dan menghapusnya tetap milik admin. Yang
--  berubah di migrasi ini hanya klaimnya sendiri.
--
--  ---------------------------------------------------------------------
--  2. TIDAK ADA TEMPAT UNTUK EMAIL PELANGGAN
--  ---------------------------------------------------------------------
--  Portal RMA beberapa brand menuntut email pelanggan saat unit
--  didaftarkan. Sampai sekarang tidak ada kolom untuk menyimpannya, jadi
--  ia dicatat di tempat lain atau tidak sama sekali.
--
--  Ditambahkan di dua tempat: klaim garansi, dan nota servis -- supaya
--  klaim yang lahir dari sebuah nota membawa emailnya ikut, sama seperti
--  nama, telepon, dan nomor seri. Di nota ia ikut kolom identitas yang
--  hanya boleh disentuh admin.
--
--  Aman dijalankan ulang.
-- =====================================================================


-- ---------------------------------------------------------------------
--  1. KOLOM EMAIL
-- ---------------------------------------------------------------------
alter table claims
  add column if not exists email text;

alter table service_orders
  add column if not exists customer_email text;


-- ---------------------------------------------------------------------
--  2. PENJAGA KOLOM KLAIM -- status dan catatan dibuka untuk teknisi
-- ---------------------------------------------------------------------
--  Bentuknya menggantikan versi di 0021. Yang berubah:
--    * blok "status + tanggal_close" dipecah -- status tidak lagi
--      diperiksa sama sekali, tanggal_close tetap dijaga (hanya
--      sinkronisasi 0016 yang boleh menggesernya, lewat penanda
--      app.sinkron_status)
--    * catatan keluar dari daftar kolom terkunci
--    * email masuk ke daftar kolom terkunci
create or replace function claims_guard_update()
returns trigger
language plpgsql security definer set search_path = public as $fn$
begin
  if not ubah_kolom_bebas() then
    -- Tanggal tutup menentukan bulan Rekap Brand, dan bulan rekap
    -- menentukan kapan sebuah unit dibayarkan. Ia diisi otomatis oleh
    -- claims_stempel_close() (0015) dan digeser hanya oleh sinkronisasi
    -- status dari nota (0016), yang menyalakan penanda ini di dalam satu
    -- transaksi. Lewat API penanda itu tidak bisa dinyalakan.
    if new.tanggal_close is distinct from old.tanggal_close
       and coalesce(current_setting('app.sinkron_status', true), 'off') <> 'on'
    then
      raise exception 'Tanggal tutup klaim diisi otomatis saat statusnya '
                      'jadi Selesai, bukan disunting langsung.';
    end if;

    -- Yang tetap milik admin: identitas unit dan pelanggan, tanggal
    -- masuk, brand, nomor RMA, dan email (dipakai brand untuk registrasi
    -- RMA). Yang DIBUKA untuk teknisi: status dan catatan di sini, part
    -- lewat claim_parts, dan teknisi sejak 0001.
    if (new.tanggal, new.brand_id, new.nama_pelanggan, new.telp, new.email,
        new.sn, new.keluhan, new.no_perbaikan, new.created_by)
       is distinct from
       (old.tanggal, old.brand_id, old.nama_pelanggan, old.telp, old.email,
        old.sn, old.keluhan, old.no_perbaikan, old.created_by)
    then
      raise exception 'Teknisi hanya boleh mengubah status, catatan, part, '
                      'dan teknisi klaim. Data unit dan pelanggan diubah admin.';
    end if;
  end if;

  new.updated_at := now();
  return new;
end;
$fn$;


-- ---------------------------------------------------------------------
--  3. PENJAGA KOLOM NOTA -- email ikut kolom identitas yang terkunci
-- ---------------------------------------------------------------------
--  Sama persis dengan versi di 0022, hanya customer_email yang
--  ditambahkan ke daftar kolom yang tidak boleh disentuh teknisi --
--  sederajat dengan customer_telp.
create or replace function service_orders_guard_update()
returns trigger
language plpgsql security definer set search_path = public as $fn$
declare
  menaut boolean :=
    coalesce(current_setting('app.taut_klaim', true), 'off') = 'on';
begin
  if not ubah_kolom_bebas() then
    if (new.no_nota, new.tanggal_masuk, new.customer_nama, new.customer_telp,
        new.customer_email, new.customer_id, new.barang_nama, new.barang_type,
        new.barang_sn, new.biaya, new.cara_bayar, new.tanggal_lunas,
        new.created_by)
       is distinct from
       (old.no_nota, old.tanggal_masuk, old.customer_nama, old.customer_telp,
        old.customer_email, old.customer_id, old.barang_nama, old.barang_type,
        old.barang_sn, old.biaya, old.cara_bayar, old.tanggal_lunas,
        old.created_by)
    then
      raise exception 'Teknisi hanya boleh mengubah status dan catatan '
                      'pekerjaan. Biaya dan data nota diubah admin.';
    end if;

    if not menaut
       and (new.garansi, new.claim_id)
           is distinct from (old.garansi, old.claim_id)
    then
      raise exception 'Tanda garansi pada nota diubah lewat klaimnya, '
                      'bukan dengan menyunting nota.';
    end if;
  end if;

  return new;
end;
$fn$;
