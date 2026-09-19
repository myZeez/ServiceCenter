-- =====================================================================
--  Migrasi 0028 : keluhan garansi diisi teknisi
--
--  Nota dan klaim masing-masing punya kolom keluhan, dan keduanya BUKAN
--  hal yang sama:
--
--    service_orders.keluhan   keluhan PELANGGAN, dicatat meja depan saat
--                             unit diterima -- "mati tiba-tiba".
--
--    claims.keluhan           keluhan GARANSI, hasil pengecekan teknisi
--                             setelah unitnya dibongkar -- "NO POWER".
--                             Inilah yang dipakai di laporan garansi dan
--                             yang dibaca brand.
--
--  Sampai sekarang keluhan klaim disalin dari nota saat klaimnya dibuat,
--  lalu dikunci hanya untuk admin. Akibatnya yang sampai ke laporan
--  garansi adalah kata-kata pelanggan, dan teknisi -- satu-satunya yang
--  tahu kerusakan sebenarnya -- tidak bisa membetulkannya. Aplikasi
--  berhenti menyalinnya (versi 2.27.0); migrasi ini membuka kolomnya
--  untuk teknisi.
--
--  Aman dijalankan ulang.
-- =====================================================================


-- ---------------------------------------------------------------------
--  1. PENJAGA KOLOM KLAIM
-- ---------------------------------------------------------------------
--  Sama persis dengan versi di 0025, kecuali keluhan yang dikeluarkan dari
--  daftar kolom yang tertutup bagi teknisi. Identitas unit dan pelanggan,
--  brand, jenis garansi, dan nomor RMA tetap milik admin.
create or replace function claims_guard_update()
returns trigger
language plpgsql security definer set search_path = public as $fn$
begin
  if not ubah_kolom_bebas() then
    if new.tanggal_close is distinct from old.tanggal_close
       and coalesce(current_setting('app.sinkron_status', true), 'off') <> 'on'
    then
      raise exception 'Tanggal tutup klaim diisi otomatis saat statusnya '
                      'jadi Selesai, bukan disunting langsung.';
    end if;

    if (new.tanggal, new.brand_id, new.jenis, new.nama_pelanggan, new.telp,
        new.email, new.sn, new.no_perbaikan, new.created_by)
       is distinct from
       (old.tanggal, old.brand_id, old.jenis, old.nama_pelanggan, old.telp,
        old.email, old.sn, old.no_perbaikan, old.created_by)
    then
      raise exception 'Teknisi hanya boleh mengubah status, keluhan garansi, '
                      'catatan, part, dan teknisi klaim. Data unit dan '
                      'pelanggan diubah admin.';
    end if;
  end if;

  new.updated_at := now();
  return new;
end;
$fn$;


-- ---------------------------------------------------------------------
--  2. KETERANGAN KOLOM
-- ---------------------------------------------------------------------
comment on column service_orders.keluhan is
  'Keluhan pelanggan, dicatat saat unit diterima. Bukan keluhan garansi -- '
  'itu claims.keluhan.';

comment on column claims.keluhan is
  'Keluhan garansi: hasil pengecekan teknisi, dipakai di laporan garansi. '
  'Tidak disalin dari keluhan nota.';
