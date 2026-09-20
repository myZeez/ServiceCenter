-- =====================================================================
--  Migrasi 0031 : awalan nomor nota menjadi SVR-
--
--  Buku toko memakai `SVR-` untuk seluruh notanya. Aplikasi menerbitkan
--  `SRV-` -- dua huruf tertukar sejak migrasi 0007, dan tidak ada yang
--  menyadarinya sampai nota buatan aplikasi bertemu nota buku dalam satu
--  laporan. Awalan yang benar `SVR-`; ini yang diputuskan pemilik toko.
--
--  Dua hal, dalam satu transaksi:
--
--    1. buat_no_nota() menerbitkan `SVR-` mulai sekarang. Tidak ada yang
--       berubah selain awalannya: tanggal DDMMYY dan angka urut lima digit
--       dari no_nota_seq tetap sama.
--
--    2. Nota yang sudah terlanjur bernomor `SRV-` diganti awalannya menjadi
--       `SVR-`. Yang diubah HANYA dua huruf itu; tanggal dan angka urutnya
--       tetap. Nota di database dan nota kertas yang sudah dipegang
--       pelanggan kini berbeda dua huruf -- angka di belakangnya sama dan
--       tetap bisa dicari lewat angka itu.
--
--  ---------------------------------------------------------------------
--  PENGAMAN
--  ---------------------------------------------------------------------
--  Kolom no_nota unique. Kalau ada nota `SRV-` yang, setelah diganti,
--  bertabrakan dengan nota `SVR-` yang sudah ada, migrasi berhenti sendiri
--  dan tidak mengubah apa pun -- termasuk fungsi di langkah 1, karena
--  seluruhnya satu transaksi. Daftar yang bertabrakan bisa dilihat dengan
--  diagnosa_awalan_nota.sql.
--
--  trg_so_touch dimatikan hanya di dalam transaksi ini. Kalau tidak,
--  setiap nota yang diganti nomornya ikut "disentuh", dan trigger itu
--  mengisi tanggal selesai / tanggal lunas yang kosong dengan hari ini --
--  persis yang dulu salah mencap 60 nota. Kalau transaksinya gagal,
--  Postgres ikut membatalkan pematiannya.
--
--  Aman dijalankan ulang: sesudah berhasil tidak ada lagi nota `SRV-`,
--  jadi langkah 2 tidak mengubah apa pun.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
--  1. PENERBIT NOMOR
-- ---------------------------------------------------------------------
create or replace function buat_no_nota()
returns text
language plpgsql volatile security definer set search_path = public as $fn$
begin
  return 'SVR-'
    || to_char(now() at time zone 'Asia/Jakarta', 'DDMMYY')
    || lpad(nextval('no_nota_seq')::text, 5, '0');
end;
$fn$;


-- ---------------------------------------------------------------------
--  2. NOTA YANG SUDAH TERLANJUR SRV-
-- ---------------------------------------------------------------------
alter table service_orders disable trigger trg_so_touch;

do $seragam$
declare
  n_kembar int;
  n_ganti  int;
  n_sisa   int;
begin
  select count(*) into n_kembar
  from service_orders a
  join service_orders b on b.no_nota = 'SVR-' || substr(a.no_nota, 5)
  where a.no_nota like 'SRV-%';

  if n_kembar > 0 then
    raise exception '% nota SRV- akan kembar dengan nota SVR- yang sudah ada. Tidak ada yang diubah.', n_kembar;
  end if;

  update service_orders
  set no_nota = 'SVR-' || substr(no_nota, 5)
  where no_nota like 'SRV-%';
  get diagnostics n_ganti = row_count;

  select count(*) into n_sisa from service_orders where no_nota like 'SRV-%';
  if n_sisa <> 0 then
    raise exception 'Masih ada % nota SRV- sesudah penggantian. Tidak ada yang diubah.', n_sisa;
  end if;

  raise notice '% nota diganti awalannya dari SRV- menjadi SVR-.', n_ganti;
end
$seragam$;

alter table service_orders enable trigger trg_so_touch;

commit;


-- ---------------------------------------------------------------------
--  Memastikan
-- ---------------------------------------------------------------------
--  SRV- harus 0, penerbit harus SVR-, dan nomor berikutnya sama seperti
--  yang terlihat di diagnosa sebelum ini -- penggantian awalan tidak boleh
--  menggeser penghitungnya.
select 'nota berawalan SRV-' as pemeriksaan,
       count(*)::text as hasil
from service_orders
where no_nota like 'SRV-%'

union all
select 'nota berawalan SVR-', count(*)::text
from service_orders
where no_nota like 'SVR-%'

union all
select 'penerbit nomor nota',
       case when prosrc like '%SVR-%' and prosrc not like '%SRV-%'
            then 'menerbitkan SVR-' else 'MASIH BELUM SVR-' end
from pg_proc
where proname = 'buat_no_nota'
  and pronamespace = 'public'::regnamespace

union all
select 'nomor urut berikutnya', nomor_nota_berikutnya()::text

union all
select 'trg_so_touch aktif lagi',
       case when (select tgenabled from pg_trigger
                  where tgrelid = 'public.service_orders'::regclass
                    and tgname = 'trg_so_touch') = 'O'
            then 'ya' else 'TIDAK -- periksa' end;
