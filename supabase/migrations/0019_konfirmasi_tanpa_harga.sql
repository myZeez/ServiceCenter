-- =====================================================================
--  Migrasi 0019 : "tunggu konfirmasi DP" tidak lagi menuntut harga
--
--  Migrasi 0018 memasang aturan: tahap 'konfirmasi' wajib punya harga,
--  dengan alasan yang terdengar masuk akal -- menunggu pelanggan
--  menyetujui angka yang belum ada tidak berarti apa-apa.
--
--  Arsipnya berkata lain. Dari 783 baris berstatus "Wait Confirm User
--  DP", 673 tidak mengisi kolom HARGA PART sama sekali -- dan 666 di
--  antaranya menuliskan harganya di kolom Catatan:
--
--    "ORI KB MODULE 1500K, BATT 1300K"
--    "LCD COVER 1300K, KB MODULE NO STOCK"
--    "ORI KB MODULE 900K, OEM CEK ATC KB ONLY 400K"
--
--  Sebabnya jelas begitu dibaca: yang ditawarkan sering LEBIH DARI SATU
--  part, masing-masing dengan harga sendiri, dan sebagiannya berupa
--  pilihan ("ori sekian, atau OEM sekian"). Satu kolom harga memang tidak
--  bisa menampung itu, dan memaksanya justru akan membuat angka yang
--  tercatat lebih miskin daripada yang benar-benar disampaikan.
--
--  Harga baru benar-benar mengikat saat uangnya berpindah. Sampai di
--  situ, 'harga' tetap boleh kosong.
--
--  Aman dijalankan ulang.
-- =====================================================================

alter table part_orders drop constraint if exists pesanan_perlu_harga;

-- tahap tidak pernah null, jadi "not in" di sini aman dari tiga-nilai.
alter table part_orders add constraint pesanan_perlu_harga
  check (tahap not in ('dipesan', 'dipasang', 'selesai')
         or harga is not null);
