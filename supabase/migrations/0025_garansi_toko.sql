-- =====================================================================
--  Migrasi 0025 : garansi toko, di samping garansi brand
--
--  Selama ini setiap klaim garansi berarti satu hal: unit rusak, part
--  diminta ke brand, brand membayar. Padahal toko juga memberi
--  garansinya sendiri -- seminggu sesudah servis, kalau unitnya rusak
--  lagi, pelanggan tidak membayar dua kali.
--
--  Keduanya sama-sama "garansi" di mata pelanggan dan sama-sama berbiaya
--  nol di notanya, tetapi berbeda pada satu hal yang menentukan: yang
--  satu ditagihkan ke brand, yang satu ditanggung toko sendiri.
--
--  ---------------------------------------------------------------------
--  YANG BERBEDA DI ANTARA KEDUANYA
--  ---------------------------------------------------------------------
--    garansi brand   nomor seri WAJIB -- brand mengenali unit dari
--                    situ, dan klaim tanpa SN tidak bisa diproses
--                    siapa pun. Masuk Rekap Brand dan bagi hasil.
--
--    garansi toko    nomor seri tidak diperlukan. Unitnya baru saja
--                    ditangani toko sendiri, notanya masih ada, dan
--                    tidak ada pihak luar yang perlu diyakinkan. TIDAK
--                    masuk Rekap Brand -- toko tidak menagih dirinya
--                    sendiri.
--
--  Brand tetap diisi pada keduanya. Bukan untuk ditagih, melainkan untuk
--  diketahui: unit merek mana yang paling sering kembali dalam masa
--  garansi toko adalah angka yang berguna, dan membuangnya berarti
--  membuang satu-satunya cara mengetahuinya.
--
--  ---------------------------------------------------------------------
--  EMAIL
--  ---------------------------------------------------------------------
--  Sudah opsional sejak 0024 dan tetap begitu -- di klaim maupun di nota.
--  Yang menuntutnya bukan aplikasi ini melainkan portal RMA sebagian
--  brand, dan itu urusan saat mendaftarkan unitnya ke sana.
--
--  Aman dijalankan ulang.
-- =====================================================================


-- ---------------------------------------------------------------------
--  1. JENISNYA
-- ---------------------------------------------------------------------
--  Teks dengan check, bukan enum. Enum di Postgres tidak bisa dikurangi
--  nilainya tanpa membangun ulang tipenya, dan daftar sependek ini tidak
--  memerlukan biaya itu.
alter table claims
  add column if not exists jenis text not null default 'brand';

do $ubah$
begin
  alter table claims drop constraint if exists jenis_garansi_dikenal;
  alter table claims add constraint jenis_garansi_dikenal
    check (jenis in ('brand', 'toko'));
end
$ubah$;

comment on column claims.jenis is
  'brand = ditagihkan ke brand, nomor seri wajib, masuk Rekap Brand. '
  'toko = ditanggung toko sendiri, nomor seri tidak diperlukan, tidak '
  'masuk Rekap Brand.';

create index if not exists klaim_jenis on claims (jenis);


-- ---------------------------------------------------------------------
--  2. NOMOR SERI TIDAK LAGI WAJIB UNTUK SEMUA
-- ---------------------------------------------------------------------
--  Kewajibannya tidak dihapus, hanya dipindahkan ke tempat yang benar:
--  dari "setiap klaim" menjadi "setiap klaim ke brand". Ditegakkan di
--  sini, bukan hanya di layar -- klaim brand tanpa SN adalah klaim yang
--  tidak bisa diproses siapa pun, dan lebih baik ditolak saat diketik
--  daripada ditemukan sebulan kemudian oleh orang di RC brand.
alter table claims alter column sn drop not null;

do $ubah$
begin
  alter table claims drop constraint if exists sn_wajib_untuk_klaim_brand;
  alter table claims add constraint sn_wajib_untuk_klaim_brand
    check (jenis <> 'brand' or coalesce(trim(sn), '') <> '');
end
$ubah$;


-- ---------------------------------------------------------------------
--  3. JENISNYA MILIK ADMIN
-- ---------------------------------------------------------------------
--  Bentuknya menggantikan versi di 0024. Yang ditambahkan hanya satu
--  kolom ke daftar yang tertutup bagi teknisi.
--
--  Alasannya uang. Memindahkan sebuah klaim dari brand ke toko
--  mengeluarkannya dari Rekap Brand -- unit itu berhenti ditagihkan, dan
--  bagi hasilnya ikut hilang. Sebaliknya, memindahkannya dari toko ke
--  brand memasukkan unit yang tidak pernah disetujui brand ke dalam
--  tagihan. Keduanya keputusan meja depan, bukan keputusan yang diambil
--  sambil menutup pekerjaan.
--
--  Saat MEMBUAT klaim, teknisi tetap bebas memilih jenisnya: penjaga ini
--  hanya berjalan pada update.
create or replace function claims_guard_update()
returns trigger
language plpgsql security definer set search_path = public as $fn$
begin
  if not ubah_kolom_bebas() then
    if new.tanggal_close is distinct from old.tanggal_close
       and coalesce(current_setting('app.sinkron_status', true), 'off') <> 'on'
    then
      raise exception 'Tanggal tutup klaim diisi otomatis saat statusnya '
                      'jadi Selesai, bukan disunting langsung.';
    end if;

    if (new.tanggal, new.brand_id, new.jenis, new.nama_pelanggan, new.telp,
        new.email, new.sn, new.keluhan, new.no_perbaikan, new.created_by)
       is distinct from
       (old.tanggal, old.brand_id, old.jenis, old.nama_pelanggan, old.telp,
        old.email, old.sn, old.keluhan, old.no_perbaikan, old.created_by)
    then
      raise exception 'Teknisi hanya boleh mengubah status, catatan, part, '
                      'dan teknisi klaim. Data unit dan pelanggan diubah admin.';
    end if;
  end if;

  new.updated_at := now();
  return new;
end;
$fn$;


-- ---------------------------------------------------------------------
--  4. PERIKSA SESUDAHNYA
-- ---------------------------------------------------------------------
--  Seluruh klaim lama menjadi 'brand', dan memang begitulah adanya:
--  sebelum migrasi ini tidak ada cara mencatat garansi toko sama sekali.
--
--    select jenis, count(*) from claims group by jenis;
--
--  Dan tidak ada klaim brand yang kehilangan nomor serinya:
--
--    select count(*) from claims
--    where jenis = 'brand' and coalesce(trim(sn), '') = '';
