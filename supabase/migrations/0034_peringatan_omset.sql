-- =====================================================================
--  Migrasi 0034 : peringatan omset menjelang ganti bulan
--
--  Setiap kali aplikasi dibuka pada hari-hari terakhir bulan, admin
--  diingatkan siapa saja teknisi yang omsetnya masih di bawah target.
--
--  Berapa hari terakhir itu -- sepuluh, sebelum ada yang mengubahnya --
--  disimpan sebagai pengaturan, bukan ditulis di dalam kode. Yang
--  mengubahnya orang yang berdiri di toko, bukan yang bisa membangun ulang
--  aplikasi.
--
--  Nol mematikan peringatannya. Batas atasnya 28: lebih dari itu berarti
--  peringatan menyala sepanjang bulan, dan peringatan yang selalu menyala
--  berhenti dibaca.
--
--  Aman dijalankan ulang.
-- =====================================================================

alter table service_settings
  add column if not exists hari_peringatan_omset smallint not null default 10
    check (hari_peringatan_omset between 0 and 28);

comment on column service_settings.hari_peringatan_omset is
  'Berapa hari terakhir sebelum ganti bulan aplikasi mengingatkan teknisi '
  'yang omsetnya masih di bawah target, setiap kali dibuka. 0 = mati.';


-- ---------------------------------------------------------------------
--  PERIKSA SESUDAHNYA
-- ---------------------------------------------------------------------
select id, target_omset, fee_admin_per_nota, hari_peringatan_omset
from service_settings;
