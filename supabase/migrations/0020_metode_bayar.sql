-- =====================================================================
--  Migrasi 0020 : cara bayar jadi daftar yang bisa diatur sendiri
--
--  Selama ini cara bayar hanya dua, dikunci sebagai enum di basis data:
--  'cash' dan 'piutang'. Kenyataannya toko menerima transfer BRI, BTN,
--  dan QRIS -- dan daftar itu akan bertambah lagi tiap kali ada rekening
--  atau dompet digital baru.
--
--  Menambahkannya sebagai nilai enum berarti satu migrasi tiap kali ada
--  bank baru, dan itu berarti menunggu aplikasi dibangun ulang untuk
--  sesuatu yang seharusnya bisa diatur sambil menjaga toko. Jadi
--  daftarnya dipindah ke tabel master, sejajar dengan brand dan jenis
--  part.
--
--  ---------------------------------------------------------------------
--  YANG SEBENARNYA DIBEDAKAN
--  ---------------------------------------------------------------------
--  'cash' bukan sekadar salah satu pilihan: ia dipakai trigger untuk
--  memutuskan sebuah nota langsung lunas atau jadi piutang. Kalau
--  transfer dan QRIS ditambahkan begitu saja, keduanya akan diperlakukan
--  seperti piutang -- uangnya sudah masuk rekening, tetapi notanya
--  tercatat belum dibayar, dan laporan pelunasan jadi salah.
--
--  Yang benar-benar membedakan bukan tunai atau bukan, melainkan uangnya
--  sudah diterima atau belum. Itulah yang sekarang disimpan, sebagai
--  kolom tersendiri.
--
--  Aman dijalankan ulang.
-- =====================================================================

-- ---------------------------------------------------------------------
--  1. TABEL MASTER
-- ---------------------------------------------------------------------
create table if not exists metode_bayar (
  id      smallint generated always as identity primary key,

  -- Yang tersimpan di nota. Dipertahankan apa adanya untuk nota lama,
  -- jadi 'cash' dan 'piutang' tidak boleh berubah ejaannya.
  kode    text     not null unique,

  nama    text     not null,

  -- Uangnya BELUM diterima saat nota ditutup. Hanya ini yang membuat
  -- sebuah nota jadi piutang; sisanya -- tunai, transfer, QRIS -- sama
  -- saja bagi kas toko.
  piutang boolean  not null default false,

  urutan  smallint not null default 0,
  aktif   boolean  not null default true
);

insert into metode_bayar (kode, nama, piutang, urutan) values
  ('cash',         'Cash',         false, 1),
  ('qris',         'QRIS',         false, 2),
  ('transfer_bri', 'Transfer BRI', false, 3),
  ('transfer_btn', 'Transfer BTN', false, 4),
  ('piutang',      'Piutang',      true,  9)
on conflict (kode) do nothing;


-- ---------------------------------------------------------------------
--  2. LEPASKAN KOLOMNYA DARI ENUM
-- ---------------------------------------------------------------------
--  Sengaja tidak dipasangi foreign key. Metode yang suatu saat
--  dinonaktifkan tidak boleh membuat nota lama gagal disimpan, dan nota
--  yang sudah tercetak harus tetap menyebut cara bayar yang tertulis di
--  kertasnya walau daftarnya berubah kemudian.
do $lepas$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'service_orders'
      and column_name = 'cara_bayar'
      and udt_name = 'cara_bayar'
  ) then
    alter table service_orders
      alter column cara_bayar type text using cara_bayar::text;

    drop type if exists cara_bayar;
  end if;
end
$lepas$;


-- ---------------------------------------------------------------------
--  3. CARA BAYAR UNTUK PESANAN PART
-- ---------------------------------------------------------------------
--  DP dan pelunasan part juga diterima lewat cara yang sama, dan sampai
--  sekarang tidak tercatat sama sekali. Saat kas dicocokkan, "masuk
--  Rp500.000" tanpa keterangan lewat mana tidak bisa dipertemukan dengan
--  mutasi rekening mana pun.
alter table part_orders
  add column if not exists cara_bayar text;


-- ---------------------------------------------------------------------
--  4. TRIGGER: LUNAS ATAU PIUTANG
-- ---------------------------------------------------------------------
--  Dulu berbunyi "cara_bayar = 'cash'". Sekarang bertanya ke daftarnya,
--  jadi metode baru apa pun yang ditandai bukan piutang langsung
--  diperlakukan benar tanpa menyentuh berkas ini lagi.
--
--  Metode yang tidak dikenal diperlakukan sebagai LUNAS, bukan piutang.
--  Itu sisi yang lebih aman untuk salah: piutang palsu akan menagih
--  pelanggan yang sudah membayar, dan itu kesalahan yang sampai ke orang
--  di depan meja.
create or replace function sentuh_service_order()
returns trigger
language plpgsql security definer set search_path = public as $fn$
begin
  new.updated_at := now();

  if new.status = 'diambil'
     and new.cara_bayar is not null
     and new.tanggal_lunas is null
     and not coalesce(
       (select m.piutang from metode_bayar m where m.kode = new.cara_bayar),
       false
     )
  then
    new.tanggal_lunas := (now() at time zone 'Asia/Jakarta')::date;
  end if;

  -- Tanggal selesai diisi sekali saja, saat pertama kali pekerjaannya
  -- dinyatakan rampung. Perubahan status berikutnya tidak menggesernya --
  -- kalau tidak, membuka kembali nota lama akan memindahkan omsetnya ke
  -- bulan berjalan.
  if new.status in ('selesai', 'diambil') and new.tanggal_selesai is null then
    new.tanggal_selesai := (now() at time zone 'Asia/Jakarta')::date;
  end if;

  return new;
end;
$fn$;


-- ---------------------------------------------------------------------
--  5. ATURAN AKSES
-- ---------------------------------------------------------------------
--  Sama seperti brand dan jenis part: semua boleh membaca -- daftarnya
--  dipakai di layar mana pun yang menampilkan nota -- hanya admin yang
--  boleh mengubah.
alter table metode_bayar enable row level security;

drop policy if exists mb_baca on metode_bayar;
create policy mb_baca on metode_bayar for select to authenticated
  using (true);

drop policy if exists mb_tulis on metode_bayar;
create policy mb_tulis on metode_bayar for all to authenticated
  using (is_admin()) with check (is_admin());


-- ---------------------------------------------------------------------
--  6. REALTIME
-- ---------------------------------------------------------------------
do $realtime$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'metode_bayar'
  ) then
    alter publication supabase_realtime add table public.metode_bayar;
  end if;

  alter table metode_bayar replica identity full;
end
$realtime$;
