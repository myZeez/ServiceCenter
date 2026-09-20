-- =====================================================================
--  Migrasi 0033 : nota batal diperlakukan seperti nota yang diambil
--
--  Unit yang dibatalkan dikembalikan ke pelanggan hari itu juga -- dalam
--  laporan toko ia "keluar", sama seperti unit yang diambil. Selama ini
--  server hanya menstempel tanggal selesai untuk Selesai dan Sudah
--  Diambil, jadi:
--
--    * nota yang dibatalkan lewat aplikasi TIDAK PERNAH muncul di Nota
--      Keluar, sedangkan yang berasal dari arsip impor muncul di tanggal
--      buku -- dua nota batal, dua perlakuan;
--    * biaya pembatalan (biaya cek, misalnya) tidak punya tanggal, jadi
--      tidak masuk laporan hari mana pun.
--
--  Yang berubah, semuanya hanya untuk nota yang BERPINDAH KE batal sesudah
--  migrasi ini:
--
--    1. tanggal_selesai distempel sekali, dengan hari laporan saat itu;
--    2. kalau pembatalannya berbiaya dan dibayar dengan cara yang bukan
--       piutang, tanggal_lunas ikut distempel -- sama seperti nota yang
--       diambil. Pembatalan tanpa biaya tidak menstempel lunas, walau ada
--       sisa cara bayar di kolomnya: tidak ada uang yang lunas.
--
--  Jalan pulangnya juga dijaga. Nota yang dibatalkan lalu dibuka kembali
--  (Masuk, Dikerjakan, Tunggu Part, atau Dikirim ke Cabang) kehilangan
--  tanggal selesainya, karena unit yang sedang dikerjakan lagi belum
--  keluar. Tanpa ini pembatalan yang salah pencet meninggalkan stempel
--  yang membuat nota aktif terus tampil di Nota Keluar -- persis yang
--  terjadi pada dua nota garansi 19 September.
--
--  Aturan jalan pulang ini sengaja HANYA untuk asal 'batal'. Yang berpindah
--  dari Selesai atau Sudah Diambil ke Dikerjakan tidak dihapus tanggalnya
--  (lihat 0023): sebagian nota arsip memang berstatus Dikerjakan dengan
--  tanggal selesai dari buku toko, dan menghapusnya mengubah laporan bulan
--  yang sudah dikirim.
--
--  Nota batal yang SUDAH ADA tidak disentuh sama sekali. Yang belum
--  bertanggal selesai dilihat dulu dengan diagnosa_nota_batal.sql.
--
--  Isinya sama dengan 0023 selain tiga hal di atas.
--
--  Aman dijalankan ulang.
-- =====================================================================

create or replace function sentuh_service_order()
returns trigger
language plpgsql security definer set search_path = public as $fn$
begin
  new.updated_at := now();

  -- Nota yang diambil -- atau dibatalkan dengan biaya -- dengan cara bayar
  -- yang bukan piutang berarti uangnya sudah diterima hari itu juga.
  if (new.status = 'diambil' or (new.status = 'batal' and new.biaya > 0))
     and new.cara_bayar is not null
     and new.tanggal_lunas is null
     and not coalesce(
       (select m.piutang from metode_bayar m where m.kode = new.cara_bayar),
       false
     )
  then
    new.tanggal_lunas := hari_laporan();
  end if;

  -- Dibuka kembali sesudah dibatalkan: unitnya belum keluar. Ditulis
  -- sebelum stempel di bawah, supaya urutan status yang aneh tidak
  -- menghapus tanggal yang baru saja diisi.
  if old.status = 'batal'
     and new.status::text in ('masuk', 'dikerjakan', 'tunggu_part', 'dikirim_cabang')
  then
    new.tanggal_selesai := null;
  end if;

  -- Tanggal selesai diisi sekali saja, saat pertama kali pekerjaannya
  -- dinyatakan rampung -- atau unitnya dibatalkan dan dikembalikan.
  -- Perubahan status berikutnya tidak menggesernya: kalau tidak, membuka
  -- kembali nota lama akan memindahkan omsetnya ke bulan berjalan.
  if new.status in ('selesai', 'diambil', 'batal')
     and new.tanggal_selesai is null
  then
    new.tanggal_selesai := hari_laporan();
  end if;

  return new;
end;
$fn$;


-- ---------------------------------------------------------------------
--  PERIKSA SESUDAHNYA
-- ---------------------------------------------------------------------
select 'trigger stempel terpasang' as pemeriksaan,
       case when prosrc ilike '%''batal''%' and prosrc ilike '%tanggal_selesai := null%'
            then 'versi 0033' else 'MASIH VERSI LAMA' end as hasil
from pg_proc
where proname = 'sentuh_service_order'
  and pronamespace = 'public'::regnamespace

union all
select 'trg_so_touch aktif',
       case when (select tgenabled from pg_trigger
                  where tgrelid = 'public.service_orders'::regclass
                    and tgname = 'trg_so_touch') = 'O'
            then 'ya' else 'TIDAK -- periksa' end;
