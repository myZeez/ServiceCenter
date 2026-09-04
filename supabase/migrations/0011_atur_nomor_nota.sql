-- =====================================================================
--  Migrasi 0011 : nomor nota bisa diatur dari halaman Setting
--
--  Sebelumnya nomor urut hanya bisa digeser lewat SQL. Padahal justru
--  saat nomornya salah -- tercetak dobel, terlanjur lompat, atau perlu
--  disambungkan ke catatan pusat -- yang memegang masalahnya adalah
--  admin di depan komputer toko, bukan orang yang bisa membuka SQL
--  Editor.
--
--  Penyimpanannya tetap sequence, bukan kolom biasa. Sequence dijamin
--  tidak pernah memberi angka sama kepada dua transaksi sekaligus; kolom
--  biasa perlu kunci manual yang mudah salah pasang.
--
--  Aman dijalankan ulang.
-- =====================================================================

-- ---------------------------------------------------------------------
--  Membaca nomor yang akan terbit berikutnya
-- ---------------------------------------------------------------------
--  Sequence yang belum pernah dipakai punya last_value = 1 dengan
--  is_called = false, dan nextval pertamanya memberi 1 -- bukan 2. Tanpa
--  memeriksa is_called, angka yang ditampilkan akan meleset satu pada
--  database yang masih baru.
create or replace function nomor_nota_berikutnya()
returns bigint
language sql stable security definer set search_path = public as $fn$
  select case when is_called then last_value + 1 else last_value end
  from no_nota_seq;
$fn$;

-- ---------------------------------------------------------------------
--  Menggeser nomor
-- ---------------------------------------------------------------------
--  Angka yang dikirim adalah nomor yang akan dipakai nota berikutnya,
--  bukan nomor terakhir yang sudah terpakai. Itu yang dilihat admin di
--  layar, jadi itu pula yang diterima fungsi ini -- supaya tidak ada
--  penerjemahan "tambah satu" yang tersembunyi di antara keduanya.
create or replace function set_nomor_nota_berikutnya(nomor bigint)
returns bigint
language plpgsql volatile security definer set search_path = public as $fn$
begin
  if not is_admin() then
    raise exception 'Hanya admin yang boleh mengubah nomor nota';
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

revoke all on function nomor_nota_berikutnya() from public;
revoke all on function set_nomor_nota_berikutnya(bigint) from public;
grant execute on function nomor_nota_berikutnya() to authenticated;
grant execute on function set_nomor_nota_berikutnya(bigint) to authenticated;

-- Penjagaannya ada di dalam fungsi, bukan pada hak akses: teknisi boleh
-- memanggil, tetapi ditolak oleh is_admin(). Dengan begitu aplikasi
-- menerima pesan yang bisa dibaca orang, bukan galat hak akses mentah.
