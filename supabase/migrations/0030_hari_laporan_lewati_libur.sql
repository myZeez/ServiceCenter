-- =====================================================================
--  Migrasi 0030 : hari libur tidak punya laporan, jadi tidak jadi tujuan
--
--  Toko tutup Sabtu (0029), dan berkas SVS yang dikirim ke pusat memang
--  tidak punya lembar Sabtu. Tetapi server menstempel tanggal_selesai
--  dan tanggal_lunas dengan hari_laporan() -- hari kalender, digeser
--  maju sesudah jam tutup 17.00 -- dan fungsi itu tidak tahu apa-apa
--  soal libur.
--
--  Akibatnya nota yang dinyatakan selesai Jumat jam 18.00 dicap Sabtu.
--  Ia tidak masuk laporan Jumat (sudah ditutup), dan tidak masuk laporan
--  mana pun sesudahnya: tab Sabtu tidak ada, jadi nota itu tercatat tapi
--  tidak pernah terbaca oleh pusat. Begitu juga nota yang diselesaikan
--  di hari libur itu sendiri.
--
--  Sekarang hari yang jatuh di hari libur bergeser ke hari kerja
--  berikutnya. Jumat sore -> Minggu, Sabtu pagi -> Minggu.
--
--  Yang TIDAK berubah: tanggal_masuk. Unit yang diterima tetap tercatat
--  di hari kalender diterimanya; menerima barang tidak ada hubungannya
--  dengan tutup buku.
--
--  Baris yang sudah ada tidak disentuh oleh berkas ini. Yang terlanjur
--  jatuh di hari libur dibetulkan terpisah, sesudah dilihat dulu.
--
--  Prasyarat: migrasi 0029 (kolom store_settings.hari_libur).
--  Aman dijalankan ulang.
-- =====================================================================

create or replace function hari_laporan(saat timestamptz default now())
returns date
language plpgsql stable security definer set search_path = public as $fn$
declare
  hari  date := ((saat at time zone 'Asia/Jakarta')
                 + make_interval(hours => 24 - jam_tutup()))::date;
  libur smallint[] := coalesce(
    (select hari_libur from store_settings where id = 1),
    '{6}'::smallint[]
  );
  geser int := 0;
begin
  -- Batas tujuh hari hanya penjaga: constraint di 0029 sudah melarang
  -- ketujuh hari libur sekaligus, jadi loop ini selalu berhenti lebih
  -- awal. Tanpa penjaga, satu pengaturan yang salah membuat setiap
  -- penyimpanan nota menggantung selamanya.
  while extract(isodow from hari)::smallint = any(libur) and geser < 7 loop
    hari  := hari + 1;
    geser := geser + 1;
  end loop;

  return hari;
end;
$fn$;

comment on function hari_laporan(timestamptz) is
  'Hari kerja yang menaungi sebuah saat: hari kalender digeser maju sesudah '
  'store_settings.tutup_jam, lalu dilewatkan ke hari kerja berikutnya kalau '
  'jatuh di store_settings.hari_libur.';


-- ---------------------------------------------------------------------
--  PERIKSA SESUDAHNYA
-- ---------------------------------------------------------------------
--  Harus: Jumat 18 sore -> Minggu 20, Sabtu 19 pagi -> Minggu 20,
--  Jumat 18 siang -> Jumat 18, Minggu 20 sore -> Senin 21.
select saat,
       to_char(saat, 'Dy HH24:MI') as waktu_wib,
       hari_laporan(saat at time zone 'Asia/Jakarta') as hari_laporan
from (values
  (timestamp '2026-09-18 12:00'),
  (timestamp '2026-09-18 18:00'),
  (timestamp '2026-09-19 09:00'),
  (timestamp '2026-09-19 18:00'),
  (timestamp '2026-09-20 10:00'),
  (timestamp '2026-09-20 18:00')
) as t(saat);
