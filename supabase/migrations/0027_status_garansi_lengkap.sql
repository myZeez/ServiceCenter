-- =====================================================================
--  Migrasi 0027 : status garansi selengkap buku garansinya
--
--  Klaim selama ini hanya punya lima status: Baru Masuk, Dikerjakan,
--  Tunggu Part, Selesai, Batal. Buku garansi toko memakai lebih banyak
--  -- WAIT APPROVAL WARRANTY, SHIP ASUS PUSAT, PART READY, CLOSE -- dan
--  saat diimpor semuanya terpaksa dilipat ke lima itu. Unit yang sedang
--  menunggu persetujuan brand tampil sebagai "Baru Masuk", seolah belum
--  disentuh siapa pun.
--
--  Daftar lengkapnya sekarang, urut menurut jalannya pekerjaan:
--
--    open            Baru Masuk
--    wait_approval   Wait Approval Warranty
--    wait_eskalasi   Wait Eskalasi Teknikal
--    wait_stok_toko  Wait Approval Stok Toko
--    proses          Dikerjakan
--    tunggu_part     Tunggu Part
--    ship            Ship
--    part_ready      Part Ready
--    ship_pusat      Ship <BRAND> Pusat -- nama brand diambil dari
--                    klaimnya, jadi klaim ASUS terbaca "Ship ASUS Pusat"
--                    dan klaim MSI "Ship MSI Pusat"
--    ok              OK
--    selesai         Selesai  -- perbaikan tuntas, unit belum diambil
--    close           Close    -- unit sudah kembali ke pelanggan
--    batal           Batal
--
--  "Selesai" dan "Close" sekarang dua hal, persis seperti "Selesai" dan
--  "Sudah Diambil" pada nota. Sebelumnya 'close' dibaca "Selesai" dan
--  memikul keduanya sekaligus.
--
--  ---------------------------------------------------------------------
--  REKAP BRAND TIDAK BERUBAH
--  ---------------------------------------------------------------------
--  Selesai maupun Close sama-sama dihitung tuntas. Bagi brand, pekerjaan
--  sudah tuntas begitu unitnya diperbaiki; kapan pelanggan datang
--  mengambil bukan urusan brand. Tanggal tutup tetap distempel sekali,
--  saat klaim PERTAMA KALI mencapai salah satu dari keduanya.
--
--  Aman dijalankan ulang.
-- =====================================================================


-- ---------------------------------------------------------------------
--  0. SISA RANCANGAN AWAL
-- ---------------------------------------------------------------------
--  Perhitungan bagi hasil versi SQL. Migrasi 0003 sudah membuangnya --
--  perhitungannya pindah ke aplikasi, dan dua rumus untuk hal yang sama
--  pasti berselisih suatu saat -- tetapi di database ini ia ternyata
--  masih hidup, entah terpasang lagi dari skrip lama. Tidak ada satu pun
--  bagian aplikasi yang membacanya.
--
--  View-nya yang menghalangi langkah 1: ia membaca claims.status, dan
--  Postgres menolak mengubah tipe kolom yang dipakai sebuah view. Ia juga
--  masih menghitung hanya klaim 'close', jadi sesudah migrasi ini
--  angkanya akan diam-diam salah.
--
--  Ada alasan kedua untuk membuangnya: view berjalan dengan hak
--  pemiliknya, bukan hak yang membacanya. Fee brand yang dikunci aturan
--  akses hanya untuk admin bisa terbaca siapa pun yang login lewat view
--  ini.
drop view if exists v_nilai_klaim;
drop function if exists ringkasan_pendapatan(date, date);
drop function if exists pendapatan_teknisi(date, date);
drop function if exists pendapatan_brand(date, date);


-- ---------------------------------------------------------------------
--  1. STATUS KLAIM JADI TEKS
-- ---------------------------------------------------------------------
--  Teks dengan check, bukan enum -- alasan yang sama dengan jenis garansi
--  di 0025. Enum yang ditambah nilainya tidak bisa langsung dipakai dalam
--  transaksi yang sama, dan SQL Editor menjalankan satu tempelan sebagai
--  satu transaksi: migrasi ini akan gagal di tengah jalan. Mengurangi
--  nilainya kelak bahkan lebih sulit lagi.
--
--  Trigger yang memantau kolom ini dilepas dulu. Postgres menolak
--  mengubah tipe kolom yang disebut dalam "update of" sebuah trigger;
--  triggernya dipasang lagi di langkah 4.
drop trigger if exists trg_claims_sinkron_status on claims;

alter table claims alter column status drop default;
alter table claims alter column status type text using status::text;
alter table claims alter column status set default 'open';

do $ubah$
begin
  alter table claims drop constraint if exists status_klaim_dikenal;
  alter table claims add constraint status_klaim_dikenal check (status in (
    'open', 'wait_approval', 'wait_eskalasi', 'wait_stok_toko', 'proses',
    'tunggu_part', 'ship', 'part_ready', 'ship_pusat', 'ok',
    'selesai', 'close', 'batal'
  ));
end
$ubah$;


-- ---------------------------------------------------------------------
--  2. PADANAN NOTA <-> KLAIM
-- ---------------------------------------------------------------------
--  Versi lama memakai tipe claim_status di tanda tangannya, jadi dibuang
--  dan dibuat ulang. Dicari lewat katalog, bukan disebut tanda tangannya,
--  supaya menjalankan ulang berkas ini tidak tersandung tipe yang sudah
--  tidak ada.
do $hapus$
declare
  f regprocedure;
begin
  for f in
    select p.oid::regprocedure
    from pg_proc p
    where p.pronamespace = 'public'::regnamespace
      and p.proname in ('status_klaim_dari_nota', 'status_nota_dari_klaim')
  loop
    execute 'drop function ' || f;
  end loop;
end
$hapus$;

-- Nota -> klaim. Nota hanya mengenal status kasar, jadi hasilnya selalu
-- salah satu dari enam status dasar klaim.
create function status_klaim_dari_nota(s service_status)
returns text
language sql immutable as $fn$
  select case s
    when 'masuk'       then 'open'
    when 'dikerjakan'  then 'proses'
    when 'tunggu_part' then 'tunggu_part'
    when 'selesai'     then 'selesai'
    when 'diambil'     then 'close'
    when 'batal'       then 'batal'
  end;
$fn$;

-- Klaim -> nota.
--
-- Status yang berurusan dengan brand -- menunggu persetujuan, kiriman ke
-- pusat, part yang sudah siap -- TIDAK pernah menarik mundur nota yang
-- sudah Selesai atau Sudah Diambil. Keadaan itu nyata: toko memakai part
-- dari stoknya sendiri, unitnya pulang ke pelanggan, dan klaimnya masih
-- "Wait Approval Stok Toko" berminggu-minggu sesudahnya. Unit yang sudah
-- di tangan pelanggan tidak boleh muncul lagi di meja sebagai
-- "Dikerjakan".
create function status_nota_dari_klaim(s text, sekarang service_status)
returns service_status
language sql immutable as $fn$
  select (case
    when s = 'open'        then 'masuk'
    when s = 'proses'      then 'dikerjakan'
    when s = 'tunggu_part' then 'tunggu_part'
    when s = 'selesai'     then 'selesai'
    when s = 'close'       then 'diambil'
    when s = 'batal'       then 'batal'
    when s in ('wait_approval', 'wait_eskalasi', 'wait_stok_toko',
               'ship', 'part_ready', 'ship_pusat', 'ok')
      then case
        when sekarang in ('selesai', 'diambil') then sekarang::text
        when s = 'ship'                         then 'tunggu_part'
        else                                         'dikerjakan'
      end
  end)::service_status;
$fn$;


-- ---------------------------------------------------------------------
--  3. SINKRONISASI DUA ARAH
-- ---------------------------------------------------------------------
--  Dua perubahan dari 0016, dan keduanya menjaga status yang lebih rinci:
--
--    * Hanya berjalan bila statusnya BENAR-BENAR berubah. Trigger
--      "update of status" ikut menyala saat kolomnya sekadar dikirim
--      ulang dengan nilai yang sama -- dan formulir nota selalu
--      mengirimnya. Tanpa syarat ini, menyimpan catatan nota saja sudah
--      menimpa "Wait Approval Warranty" dengan "Dikerjakan".
--
--    * Klaim yang statusnya masih sejalan dengan notanya dibiarkan.
--      "Part Ready" sejalan dengan nota "Dikerjakan"; memaksanya menjadi
--      "Dikerjakan" berarti membuang kabar yang justru dicatat untuk
--      dibaca.
create or replace function sinkron_status_ke_klaim()
returns trigger
language plpgsql security definer set search_path = public as $fn$
declare
  tujuan text;
begin
  if new.claim_id is null then return null; end if;

  if tg_op = 'UPDATE'
     and new.status is not distinct from old.status
     and new.claim_id is not distinct from old.claim_id
  then
    return null;
  end if;

  tujuan := status_klaim_dari_nota(new.status);
  if tujuan is null then return null; end if;

  perform set_config('app.sinkron_status', 'on', true);

  update claims
  set status = tujuan,
      tanggal_close = case
        when tujuan in ('selesai', 'close')
          then coalesce(tanggal_close, new.tanggal_selesai)
        else tanggal_close
      end
  where id = new.claim_id
    and status_nota_dari_klaim(status, new.status)
        is distinct from new.status;

  perform set_config('app.sinkron_status', 'off', true);
  return null;
end;
$fn$;

create or replace function sinkron_status_ke_nota()
returns trigger
language plpgsql security definer set search_path = public as $fn$
begin
  if new.status is not distinct from old.status then return null; end if;

  perform set_config('app.sinkron_status', 'on', true);

  update service_orders so
  set status = status_nota_dari_klaim(new.status, so.status)
  where so.claim_id = new.id
    and so.status
        is distinct from status_nota_dari_klaim(new.status, so.status);

  perform set_config('app.sinkron_status', 'off', true);
  return null;
end;
$fn$;


-- ---------------------------------------------------------------------
--  4. TANGGAL TUTUP, DAN TRIGGER YANG DILEPAS DI LANGKAH 1
-- ---------------------------------------------------------------------
create or replace function claims_stempel_close()
returns trigger
language plpgsql security definer set search_path = public as $fn$
begin
  if new.status in ('selesai', 'close') and new.tanggal_close is null then
    new.tanggal_close := (now() at time zone 'Asia/Jakarta')::date;
  end if;
  return new;
end;
$fn$;

create trigger trg_claims_sinkron_status
  after update of status on claims
  for each row execute function sinkron_status_ke_nota();

-- Tipe lamanya sudah tidak dipakai kolom maupun fungsi mana pun. Kalau
-- ternyata masih ada yang memakainya, dibiarkan saja -- tipe yang
-- menganggur tidak merugikan apa pun, sedangkan migrasi yang gagal di
-- baris terakhir membatalkan semua yang di atasnya.
do $buang$
begin
  drop type if exists claim_status;
exception when dependent_objects_still_exist then
  raise notice 'Tipe claim_status masih dipakai; dibiarkan.';
end
$buang$;


-- ---------------------------------------------------------------------
--  5. MENGEMBALIKAN STATUS YANG DULU TERPAKSA DILIPAT
-- ---------------------------------------------------------------------
--  Klaim hasil impor 2026 yang di buku garansinya berstatus rinci. Hanya
--  yang statusnya masih persis hasil impor; yang sudah diubah dari
--  aplikasi dilewati.
update claims c
set status = v.status
from (values
  ('IDD7W90013',   'wait_approval'),
  ('IDD7W90014',   'wait_approval'),
  ('IDD7W90016',   'ship_pusat'),
  ('ADH260728006', 'wait_stok_toko')
) as v(no_perbaikan, status)
where c.no_perbaikan = v.no_perbaikan
  and c.status = 'open';

-- Klaim Canon berstatus PART READY tidak punya nomor perbaikan.
update claims
set status = 'part_ready'
where sn = 'AGVY59246'
  and status = 'proses';

-- Klaim yang dulu ditutup lewat nota "Selesai". Unitnya masih di rak,
-- jadi yang benar adalah Selesai, bukan Close. Tanggal tutupnya tidak
-- berubah, begitu pula rekapnya.
update claims c
set status = 'selesai'
from service_orders so
where so.claim_id = c.id
  and c.status = 'close'
  and so.status = 'selesai';


-- ---------------------------------------------------------------------
--  PERIKSA SESUDAHNYA
-- ---------------------------------------------------------------------
select status, count(*) as klaim
from claims
group by status
order by count(*) desc;
