-- =====================================================================
--  Migrasi 0029 : hari libur toko
--
--  Toko tutup setiap Sabtu. Di berkas SVS bulanan hal itu terlihat
--  sebagai tab yang memang tidak ada -- 01, 02, 03, 04, 06 -- sementara
--  aplikasi tetap menerbitkan satu tab untuk tiap tanggal kalender, jadi
--  ekspornya memuat tab Sabtu yang kosong melompong dan tidak ada di
--  lembar yang dikirim ke pusat.
--
--  Harinya disimpan sebagai pengaturan, bukan ditulis di dalam kode.
--  Hari libur bisa bergeser -- libur nasional, cuti bersama, atau
--  keputusan baru -- dan yang mengubahnya orang yang sedang berdiri di
--  toko, bukan yang bisa membuka SQL Editor.
--
--  Nomor harinya mengikuti ISO, sama dengan DateTime.weekday di Dart:
--  1 Senin, 2 Selasa, 3 Rabu, 4 Kamis, 5 Jumat, 6 Sabtu, 7 Minggu.
--
--  Aman dijalankan ulang.
-- =====================================================================

alter table store_settings
  add column if not exists hari_libur smallint[] not null default '{6}';

do $ubah$
begin
  alter table store_settings drop constraint if exists hari_libur_masuk_akal;
  alter table store_settings add constraint hari_libur_masuk_akal
    check (
      hari_libur <@ array[1, 2, 3, 4, 5, 6, 7]::smallint[]
      -- Tujuh hari libur berarti toko tidak pernah buka. Yang begitu
      -- bukan pengaturan, melainkan salah pencet.
      and array_length(hari_libur, 1) is distinct from 7
    );
end
$ubah$;

comment on column store_settings.hari_libur is
  'Hari toko tutup, nomor ISO: 1 Senin sampai 7 Minggu. Laporan harian '
  'menandainya libur, dan ekspor bulanan tidak menerbitkan tabnya.';


-- ---------------------------------------------------------------------
--  PERIKSA SESUDAHNYA
-- ---------------------------------------------------------------------
select id, nama, tutup_jam, hari_libur from store_settings;
