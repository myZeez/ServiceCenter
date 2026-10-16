-- Status klaim garansi dan status nota servis adalah dua keadaan berbeda.
--
-- Klaim menerangkan proses dengan brand (approval, part, close), sedangkan
-- nota menerangkan posisi unit pelanggan (dikerjakan, dikirim ke cabang,
-- selesai, diambil). Sebelumnya dua trigger menyalin salah satunya ke yang
-- lain; akibatnya status Close klaim memaksa nota menjadi Diambil dan
-- perubahan nota dapat menimpa informasi proses klaim.
--
-- Tidak ada data yang diubah di sini. Status nota yang sudah tersimpan tetap
-- menjadi catatan posisi unit saat ini dan dapat dilengkapi lewat aplikasi.

begin;

drop trigger if exists trg_so_sinkron_status on public.service_orders;
drop trigger if exists trg_claims_sinkron_status on public.claims;

commit;