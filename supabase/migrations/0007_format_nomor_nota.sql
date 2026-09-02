-- =====================================================================
--  Migrasi 0007 : format nomor nota SRV-DDMMYY0001
--
--  Tanggal di dalam nomor sekadar keterangan; angka urutnya berjalan terus
--  tanpa pernah mengulang, jadi nomor urut terakhir sekaligus menunjukkan
--  jumlah nota yang pernah dibuat.
--
--  Aman dijalankan ulang.
-- =====================================================================

-- Memakai sequence, bukan menghitung max() dari tabel. Sequence dijamin
-- tidak pernah memberi angka sama kepada dua transaksi sekaligus, tanpa
-- perlu kunci manual.
--
-- Konsekuensinya nomor bisa berlubang bila penyimpanan gagal di tengah
-- jalan: angka yang sudah diambil tidak dikembalikan. Itu pilihan yang
-- disengaja -- nomor yang lompat masih bisa dijelaskan, nomor kembar pada
-- nota yang sudah tercetak tidak.
create sequence if not exists no_nota_seq start 1;

create or replace function buat_no_nota()
returns text
language plpgsql volatile security definer set search_path = public as $fn$
begin
  return 'SRV-'
    || to_char(now() at time zone 'Asia/Jakarta', 'DDMMYY')
    || lpad(nextval('no_nota_seq')::text, 4, '0');
end;
$fn$;
