-- =====================================================================
--  Migrasi 0010 : angka urut nota jadi 5 digit
--
--  Pusat membaca nomor nota dengan mengambil 5 digit terakhirnya, karena
--  angka itulah jumlah nota yang pernah dibuat toko. Dengan 4 digit,
--  digit terakhir tahun ikut terbawa dan angkanya jadi salah baca:
--
--    SRV-0309260001  ->  5 digit terakhir "60001"   (salah)
--    SRV-03092600001 ->  5 digit terakhir "00001"   (benar)
--
--  Tanggal di depan tetap sekadar keterangan. Yang dijaga tetap sama:
--  angka urutnya berjalan terus tanpa pernah mengulang.
--
--  Aman dijalankan ulang.
-- =====================================================================

create or replace function buat_no_nota()
returns text
language plpgsql volatile security definer set search_path = public as $fn$
begin
  return 'SRV-'
    || to_char(now() at time zone 'Asia/Jakarta', 'DDMMYY')
    || lpad(nextval('no_nota_seq')::text, 5, '0');
end;
$fn$;

-- Nota lama tetap dibiarkan apa adanya. Sebagian sudah tercetak dan
-- dipegang pelanggan; nomor di kertas dan nomor di database harus tetap
-- sama, meski panjangnya berbeda dari nota baru.

-- ---------------------------------------------------------------------
--  Menyambung nomor dari catatan toko yang berjalan
-- ---------------------------------------------------------------------
--  Sequence ini dimulai dari 1, jadi nota pertama dari aplikasi bernomor
--  00001. Kalau toko sudah punya hitungan berjalan sendiri -- misalnya
--  nota terakhir di pusat tercatat 28112 -- nomor aplikasi perlu
--  disambung ke sana supaya laporan hariannya nyambung dengan laporan
--  pusat sebelumnya.
--
--  Ganti angkanya dengan nomor nota terakhir yang sudah terpakai, lalu
--  jalankan satu baris ini. Nota berikutnya akan bernomor angka itu + 1.
--
--    select setval('no_nota_seq', 28112);
--
--  Sengaja tidak dijalankan otomatis: angkanya hanya diketahui dari
--  catatan toko, dan menaikkannya tidak bisa dibatalkan tanpa risiko
--  menerbitkan nomor kembar.
