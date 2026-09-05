-- =====================================================================
--  Migrasi 0016 : status nota servis dan klaim garansi berjalan bersama
--
--  Unit bergaransi menghasilkan dua catatan: nota untuk pelanggan dan
--  klaim untuk brand. Sejak awal keduanya hanya ditautkan sekali saat
--  dibuat, lalu dibiarkan jalan sendiri-sendiri. Akibatnya admin menutup
--  pekerjaan di halaman Servis, dan klaimnya tetap tertinggal di "Baru
--  Masuk" -- padahal fisiknya unit yang sama.
--
--  Sejak ada halaman Rekap Brand, selisih itu bukan lagi sekadar
--  membingungkan: yang masuk rekap bulanan hanyalah klaim berstatus
--  Selesai. Klaim yang tertinggal berarti unit yang tidak pernah
--  ditagihkan ke brand, dan tidak pernah ikut dibagi hasilnya.
--
--  Migrasi ini menyatukan keduanya ke dua arah. Diubah dari nota, klaimnya
--  ikut; diubah dari klaim, notanya ikut -- khusus nota yang bergaransi.
--
--  Aman dijalankan ulang.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. PADANANNYA
--
--    Ditulis sekali, di sini, sebagai fungsi. Bukan disalin ke Dart:
--    dua salinan aturan yang sama pasti berbeda suatu saat, dan yang
--    ketahuan belakangan adalah unit yang tidak pernah masuk rekap.
--
--    Kedua daftar status hampir sebangun. Yang tidak punya pasangan
--    persis cuma satu: nota membedakan "Selesai" dari "Sudah Diambil",
--    klaim tidak. Bagi brand, pekerjaannya memang sudah tuntas begitu
--    unitnya diperbaiki -- menunggu pelanggan datang mengambil adalah
--    urusan meja depan, bukan urusan brand.
-- ---------------------------------------------------------------------
create or replace function status_klaim_dari_nota(s service_status)
returns claim_status
language sql immutable as $fn$
  select (case s
    when 'masuk'       then 'open'
    when 'dikerjakan'  then 'proses'
    when 'tunggu_part' then 'tunggu_part'
    when 'selesai'     then 'close'
    when 'diambil'     then 'close'
    when 'batal'       then 'batal'
  end)::claim_status;
$fn$;

-- Arah sebaliknya butuh keadaan notanya sekarang. "Selesai" pada klaim
-- hanya berarti perbaikannya tuntas; apakah pelanggan sudah mengambil
-- unitnya adalah kabar yang tidak pernah sampai ke klaim. Karena itu nota
-- yang sudah "Sudah Diambil" tidak pernah ditarik mundur jadi "Selesai".
create or replace function status_nota_dari_klaim(
  s        claim_status,
  sekarang service_status
)
returns service_status
language sql immutable as $fn$
  select (case
    when s = 'open'                              then 'masuk'
    when s = 'proses'                            then 'dikerjakan'
    when s = 'tunggu_part'                       then 'tunggu_part'
    when s = 'close' and sekarang = 'diambil'    then 'diambil'
    when s = 'close'                             then 'selesai'
    when s = 'batal'                             then 'batal'
  end)::service_status;
$fn$;


-- ---------------------------------------------------------------------
-- 2. PENJAGA KOLOM KLAIM
--
--    Status klaim tetap tertutup bagi teknisi, seperti sebelumnya. Yang
--    dibuka hanya satu jalan: perubahan yang datang dari nota servis.
--    Teknisi memang berhak menutup pekerjaannya dari sana sejak migrasi
--    0014 -- yang tidak boleh adalah menyentuh klaimnya langsung.
--
--    Tanggal tutup ikut dalam kelonggaran yang sama, dan harus ikut:
--    menutup sebuah klaim berarti menuliskan kapan ia ditutup. Dipisahkan,
--    yang terjadi adalah sinkronisasi yang berhasil separuh -- statusnya
--    berubah, tanggalnya ditolak, dan seluruh penyimpanan nota ikut gagal.
--    Di luar jalan itu tanggalnya tetap tertutup, karena ia yang
--    menentukan sebuah unit masuk rekap bulan yang mana.
--
--    Penandanya berumur satu transaksi dan hanya bisa dipasang dari dalam
--    trigger di bawah. Lewat API tidak ada cara menyalakannya: PostgREST
--    hanya membuka fungsi di skema public, sedangkan set_config tinggal
--    di pg_catalog.
--
--    Kolom selebihnya dijaga persis seperti aslinya, tanpa kelonggaran
--    apa pun.
-- ---------------------------------------------------------------------
create or replace function claims_guard_update()
returns trigger
language plpgsql security definer set search_path = public as $fn$
begin
  if not is_admin() then
    if (new.status, new.tanggal_close)
       is distinct from (old.status, old.tanggal_close)
       and coalesce(current_setting('app.sinkron_status', true), 'off') <> 'on'
    then
      raise exception 'Teknisi hanya boleh mengubah kolom teknisi.';
    end if;

    if (new.tanggal, new.brand_id, new.nama_pelanggan, new.telp, new.sn,
        new.keluhan, new.no_perbaikan, new.catatan, new.created_by)
       is distinct from
       (old.tanggal, old.brand_id, old.nama_pelanggan, old.telp, old.sn,
        old.keluhan, old.no_perbaikan, old.catatan, old.created_by)
    then
      raise exception 'Teknisi hanya boleh mengubah kolom teknisi.';
    end if;
  end if;

  new.updated_at := now();
  return new;
end;
$fn$;


-- ---------------------------------------------------------------------
-- 3. NOTA  ->  KLAIM
--
--    Ikut menuliskan tanggal tutup dari tanggal selesai notanya. Kalau
--    tidak, stempel di migrasi 0015 mengisinya dengan hari ini, dan unit
--    yang selesai bulan lalu jatuh ke rekap bulan berjalan.
-- ---------------------------------------------------------------------
create or replace function sinkron_status_ke_klaim()
returns trigger
language plpgsql security definer set search_path = public as $fn$
declare
  tujuan claim_status;
begin
  if new.claim_id is null then return null; end if;

  tujuan := status_klaim_dari_nota(new.status);
  if tujuan is null then return null; end if;

  perform set_config('app.sinkron_status', 'on', true);

  update claims
  set status = tujuan,
      tanggal_close = case
        when tujuan = 'close'
          then coalesce(tanggal_close, new.tanggal_selesai)
        else tanggal_close
      end
  where id = new.claim_id
    and status is distinct from tujuan;

  perform set_config('app.sinkron_status', 'off', true);
  return null;
end;
$fn$;

-- Ikut dijalankan saat nota dibuat: aplikasi menerbitkan klaimnya lebih
-- dulu dengan status awal, dan notanya bisa saja langsung dicatat pada
-- keadaan yang lebih maju dari itu.
drop trigger if exists trg_so_sinkron_status on service_orders;
create trigger trg_so_sinkron_status
  after insert or update of status, claim_id on service_orders
  for each row execute function sinkron_status_ke_klaim();


-- ---------------------------------------------------------------------
-- 4. KLAIM  ->  NOTA
--
--    Berhenti sendiri, tanpa penjaga kedalaman: tiap sisi hanya menulis
--    bila nilainya memang berbeda, jadi pantulan baliknya selalu berupa
--    UPDATE yang tidak menyentuh baris mana pun.
-- ---------------------------------------------------------------------
create or replace function sinkron_status_ke_nota()
returns trigger
language plpgsql security definer set search_path = public as $fn$
begin
  perform set_config('app.sinkron_status', 'on', true);

  update service_orders so
  set status = status_nota_dari_klaim(new.status, so.status)
  where so.claim_id = new.id
    and so.status is distinct from status_nota_dari_klaim(new.status, so.status);

  perform set_config('app.sinkron_status', 'off', true);
  return null;
end;
$fn$;

drop trigger if exists trg_claims_sinkron_status on claims;
create trigger trg_claims_sinkron_status
  after update of status on claims
  for each row execute function sinkron_status_ke_nota();


-- ---------------------------------------------------------------------
-- 5. MEMBERESKAN YANG SUDAH TERLANJUR BERSELISIH
--
--    Notanya yang dipakai sebagai acuan, karena di situlah pekerjaannya
--    selama ini dicatat.
--
--    Klaim yang sudah Selesai atau Batal sengaja tidak disentuh. Menarik
--    mundur klaim yang sudah ditutup akan mengeluarkannya dari Rekap
--    Brand -- termasuk yang mungkin sudah terlanjur dicocokkan dengan
--    surat brand dan dibayarkan.
--
--    Penandanya dipasang karena migrasi ini dijalankan di SQL Editor,
--    tempat auth.uid() kosong dan is_admin() karenanya bernilai palsu.
-- ---------------------------------------------------------------------
do $backfill$
begin
  perform set_config('app.sinkron_status', 'on', true);

  update claims c
  set status = status_klaim_dari_nota(so.status),
      tanggal_close = case
        when status_klaim_dari_nota(so.status) = 'close'
          then coalesce(c.tanggal_close, so.tanggal_selesai,
                        (now() at time zone 'Asia/Jakarta')::date)
        else c.tanggal_close
      end
  from service_orders so
  where so.claim_id = c.id
    and c.status not in ('close', 'batal')
    and c.status is distinct from status_klaim_dari_nota(so.status);

  perform set_config('app.sinkron_status', 'off', true);
end;
$backfill$;
