-- =====================================================================
--  Migrasi 0013 : teknisi boleh melihat pekerjaan dan omsetnya sendiri
--
--  Sebelum ini, service_orders dan service_settings tertutup rapat untuk
--  admin saja. Akibatnya teknisi tidak bisa melihat berapa unit yang
--  sedang dipegangnya maupun berapa omset yang sudah dihasilkannya --
--  padahal target 4 juta sebulan itu memang ditujukan kepada mereka, dan
--  target yang tidak bisa dilihat pemiliknya tidak berguna sebagai target.
--
--  Yang dibuka hanya membaca, dan hanya barisnya sendiri. Menyimpan dan
--  mengubah nota tetap milik admin.
--
--  Aman dijalankan ulang.
-- =====================================================================

-- ---------------------------------------------------------------------
--  Nota yang dikerjakannya sendiri
-- ---------------------------------------------------------------------
--  Aturan di Postgres bersifat menambah: kebijakan admin yang sudah ada
--  tetap berlaku penuh, dan yang ini hanya menambahkan satu jalan baca
--  yang jauh lebih sempit di sebelahnya.
--
--  Batasnya teknisi_id, bukan created_by: yang berhak melihat sebuah nota
--  adalah orang yang mengerjakan unitnya, bukan orang yang mengetiknya.
drop policy if exists so_teknisi_baca on service_orders;
create policy so_teknisi_baca on service_orders for select to authenticated
  using (is_active_user() and teknisi_id = auth.uid());

-- ---------------------------------------------------------------------
--  Aturan omset
-- ---------------------------------------------------------------------
--  Isinya dua angka: target omset teknisi dan fee admin per nota. Yang
--  pertama memang harus diketahui teknisi. Yang kedua ikut terbaca, dan
--  itu diterima -- angkanya aturan toko, bukan penghasilan seseorang.
--
--  Fee garansi dari brand tetap tertutup: itu ada di brand_fees dan
--  revenue_settings, yang tidak disentuh migrasi ini.
drop policy if exists servis_setting_baca on service_settings;
create policy servis_setting_baca on service_settings for select to authenticated
  using (is_active_user());
