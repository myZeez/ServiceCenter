-- =====================================================================
--  Migrasi 0066 : yang hanya boleh dikelola super admin
--
--  PASANG SETELAH: 0065, akun super admin sudah ada, dan aplikasi versi baru
--  terpasang. Berkas ini berhenti sendiri kalau belum ada super admin aktif.
--
--  DEPLOY BERSAMAAN: edge function create-technician versi baru. Fungsi itu
--  memakai service role sehingga melewati RLS: dengan versi lama, super admin
--  ditolak menambah pengguna dan admin tetap boleh.
--
--  Admin meja depan tetap menerima servis, mengelola klaim, mencatat
--  pelunasan, dan mengimpor data. Yang pindah ke super admin: pengguna, data
--  master, aturan toko, fee dan bagi hasil, rekap brand, dan kirim partner.
--
--  Yang dibaca aplikasi admin tetap boleh dibaca: brands, part_types,
--  metode_bayar, store_settings, service_settings, dan part_settings. Yang
--  tidak dipakai layar admin ditutup sekalian, supaya angkanya memang tidak
--  sampai ke perangkatnya, bukan sekadar tidak ditampilkan.
--
--  Omset per teknisi tetap terbuka bagi admin: dialah yang mendorong omset,
--  jadi harus tahu siapa yang masih kurang.
--
--  Aman dijalankan ulang.
-- =====================================================================

do $periksa$
begin
  if not exists (select 1 from public.profiles where role::text = 'super_admin' and aktif) then
    raise exception 'Belum ada super admin aktif. Tidak ada yang diubah.';
  end if;
end
$periksa$;

-- Pengguna
drop policy if exists profiles_write on public.profiles;
create policy profiles_write on public.profiles
  for all to authenticated using (is_super_admin()) with check (is_super_admin());

-- Data master dan aturan toko. Kebijakan bacanya tetap.
drop policy if exists brands_write on public.brands;
create policy brands_write on public.brands
  for all to authenticated using (is_super_admin()) with check (is_super_admin());

drop policy if exists parts_write on public.part_types;
create policy parts_write on public.part_types
  for all to authenticated using (is_super_admin()) with check (is_super_admin());

drop policy if exists mb_tulis on public.metode_bayar;
create policy mb_tulis on public.metode_bayar
  for all to authenticated using (is_super_admin()) with check (is_super_admin());

drop policy if exists toko_ubah on public.store_settings;
create policy toko_ubah on public.store_settings
  for all to authenticated using (is_super_admin()) with check (is_super_admin());

drop policy if exists servis_setting_admin on public.service_settings;
create policy servis_setting_admin on public.service_settings
  for all to authenticated using (is_super_admin()) with check (is_super_admin());

-- Up toko penjualan part: admin tetap perlu membacanya untuk menghitung harga.
drop policy if exists ps_admin on public.part_settings;
create policy ps_admin on public.part_settings
  for all to authenticated using (is_super_admin()) with check (is_super_admin());
drop policy if exists ps_admin_baca on public.part_settings;
create policy ps_admin_baca on public.part_settings
  for select to authenticated using (is_admin());

-- Fee, bagi hasil, dan pendapatan. Admin SC tetap boleh membaca fee dan rekap
-- brand seperti sebelumnya.
drop policy if exists fees_admin on public.brand_fees;
create policy fees_admin on public.brand_fees
  for all to authenticated using (is_super_admin()) with check (is_super_admin());
drop policy if exists fees_admin_sc_baca on public.brand_fees;
create policy fees_admin_sc_baca on public.brand_fees
  for select to authenticated using (is_super_admin() or is_admin_sc());

drop policy if exists settlements_admin on public.claim_settlements;
create policy settlements_admin on public.claim_settlements
  for all to authenticated using (is_super_admin()) with check (is_super_admin());
drop policy if exists settlements_admin_sc_baca on public.claim_settlements;
create policy settlements_admin_sc_baca on public.claim_settlements
  for select to authenticated using (is_super_admin() or is_admin_sc());

drop policy if exists brand_rules_admin on public.brand_revenue_rules;
create policy brand_rules_admin on public.brand_revenue_rules
  for all to authenticated using (is_super_admin()) with check (is_super_admin());

drop policy if exists brand_shares_admin on public.brand_technician_shares;
create policy brand_shares_admin on public.brand_technician_shares
  for all to authenticated using (is_super_admin()) with check (is_super_admin());

drop policy if exists settings_admin on public.revenue_settings;
create policy settings_admin on public.revenue_settings
  for all to authenticated using (is_super_admin()) with check (is_super_admin());

-- Kirim partner hanya tersedia bagi super admin.
drop policy if exists service_partner_admin on public.service_partner_orders;
create policy service_partner_admin on public.service_partner_orders
  for all to authenticated using (is_super_admin()) with check (is_super_admin());

-- Nomor nota termasuk pengaturan.
create or replace function public.set_nomor_nota_berikutnya(nomor bigint)
returns bigint
language plpgsql security definer
set search_path = public
as $fn$
begin
  if not is_super_admin() then
    raise exception 'Hanya super admin yang boleh mengubah nomor nota';
  end if;

  if nomor is null or nomor < 1 then
    raise exception 'Nomor nota harus 1 atau lebih';
  end if;

  -- is_called = false membuat nextval berikutnya memberi tepat `nomor`,
  -- bukan `nomor` + 1.
  perform setval('no_nota_seq', nomor, false);
  return nomor;
end;
$fn$;
