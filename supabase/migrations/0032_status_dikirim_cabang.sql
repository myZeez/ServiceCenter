-- =====================================================================
--  Migrasi 0032 : status "Dikirim ke Cabang"
--
--  Unit yang dikerjakan di cabang lain -- Pangkalan Bun, Sampit, Kasongan,
--  Lamandau -- sampai sekarang tidak punya status. Ia dicatat sebagai
--  "Dikerjakan" atau "Tunggu Part" dan tidak ada yang tahu unitnya sedang
--  tidak ada di rak, sampai pelanggan menanyakannya.
--
--  Statusnya baru, dan membawa dua keterangan yang hanya berlaku
--  untuknya: cabang tujuan dan tanggal unit dikirim. Aplikasi merangkainya
--  menjadi
--
--      Unit dikirim ke Cabang Pangkalan Bun Tanggal 08-09-2026
--
--  Keterangannya disimpan sebagai dua kolom, bukan sebagai kalimat, supaya
--  cabang dan tanggalnya bisa disaring dan diubah satu per satu.
--
--  Daftar cabangnya ada di pengaturan toko, bukan di dalam kode: cabang
--  bisa bertambah, dan yang menambahkannya orang yang berdiri di toko.
--
--  ---------------------------------------------------------------------
--  KENAPA BATASANNYA MEMAKAI ::text
--  ---------------------------------------------------------------------
--  Nilai enum yang baru ditambahkan tidak boleh dipakai di transaksi yang
--  sama, dan SQL Editor menjalankan satu tempelan sebagai satu transaksi.
--  Menulis 'dikirim_cabang' begitu saja di dalam batasan membuat migrasi
--  ini gagal di tengah jalan. Membandingkan status::text dengan teks biasa
--  tidak memakai nilai enumnya, jadi lolos.
--
--  Aman dijalankan ulang.
-- =====================================================================


-- ---------------------------------------------------------------------
--  1. STATUS BARU
-- ---------------------------------------------------------------------
--  Status nota menghitung unitnya masih berjalan (bukan tuntas), jadi
--  tidak ada satu pun trigger stempel tanggal selesai yang tersentuh --
--  sama seperti Tunggu Part. Padanan di klaim garansi juga tidak ada:
--  status_klaim_dari_nota() mengembalikan kosong untuk nilai yang tidak
--  dikenalnya, dan sinkronisasi ke klaim berhenti di situ.
alter type service_status add value if not exists 'dikirim_cabang';


-- ---------------------------------------------------------------------
--  2. KETERANGAN PENGIRIMAN PADA NOTA
-- ---------------------------------------------------------------------
--  Dibiarkan saat statusnya berpindah lagi: cabang dan tanggal itu jejak
--  ke mana unitnya pernah dikirim, dan menghapusnya diam-diam berarti
--  membuang catatan. Aplikasi hanya menampilkannya selama statusnya masih
--  Dikirim ke Cabang.
alter table service_orders
  add column if not exists cabang_tujuan text,
  add column if not exists tanggal_kirim date;

do $ubah$
begin
  alter table service_orders drop constraint if exists kirim_cabang_lengkap;
  alter table service_orders add constraint kirim_cabang_lengkap
    check (
      status::text <> 'dikirim_cabang'
      or (nullif(btrim(cabang_tujuan), '') is not null
          and tanggal_kirim is not null)
    );
end
$ubah$;

comment on column service_orders.cabang_tujuan is
  'Cabang tujuan unit yang dikirim. Wajib selama status = dikirim_cabang; '
  'sesudahnya dibiarkan sebagai jejak.';
comment on column service_orders.tanggal_kirim is
  'Tanggal unit dikirim ke cabang. Wajib selama status = dikirim_cabang.';


-- ---------------------------------------------------------------------
--  3. DAFTAR CABANG
-- ---------------------------------------------------------------------
--  Nama cabang di nota disalin sebagai teks, tidak menunjuk ke daftar ini.
--  Cabang yang kelak dihapus dari daftar tidak mengubah nota lama.
alter table store_settings
  add column if not exists cabang text[] not null
    default array['Pangkalan Bun', 'Sampit', 'Kasongan', 'Lamandau'];

do $ubah$
begin
  alter table store_settings drop constraint if exists cabang_masuk_akal;
  alter table store_settings add constraint cabang_masuk_akal
    check (
      coalesce(cardinality(cabang), 0) <= 30
      and array_position(cabang, '') is null
    );
end
$ubah$;

comment on column store_settings.cabang is
  'Cabang tujuan pengiriman unit. Dipilih di nota yang berstatus '
  'dikirim_cabang.';


-- ---------------------------------------------------------------------
--  PERIKSA SESUDAHNYA
-- ---------------------------------------------------------------------
--  Nilai enum dibaca dari katalog, bukan dengan menyebutnya: yang kedua
--  memakai nilainya di transaksi yang sama dan akan ditolak.
select 'status nota' as pemeriksaan,
       string_agg(enumlabel, ', ' order by enumsortorder) as hasil
from pg_enum
where enumtypid = 'service_status'::regtype

union all
select 'kolom nota',
       string_agg(column_name, ', ' order by column_name)
from information_schema.columns
where table_schema = 'public' and table_name = 'service_orders'
  and column_name in ('cabang_tujuan', 'tanggal_kirim')

union all
select 'batasan nota',
       case when exists (select 1 from pg_constraint where conname = 'kirim_cabang_lengkap')
            then 'kirim_cabang_lengkap ada' else 'TIDAK ADA' end

union all
select 'daftar cabang', array_to_string(cabang, ', ')
from store_settings
where id = 1;
