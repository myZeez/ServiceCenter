-- =====================================================================
--  Migrasi 0017 : tanya harga dan pemesanan part
--
--  Unit non-garansi yang partnya harus dibeli selama ini tidak punya
--  tempat sama sekali. Pelanggan datang, partnya dicari, harganya
--  ditawarkan -- dan semua itu hanya ada di kepala orang yang melayani.
--  Begitu ada lima orang bertanya di hari yang sama, satu pasti terlupa.
--
--  Yang dicatat di sini adalah BARANGNYA. Jasa memasangnya tetap masuk
--  nota servis seperti biasa, dan dari sanalah ia ikut omset dan bagi
--  hasil. Keduanya sengaja tidak dicampur: untung penjualan part bukan
--  hasil kerja teknisi, dan mencampurnya membuat kedua angka itu tidak
--  bisa dibaca lagi.
--
--  Aman dijalankan ulang.
-- =====================================================================

-- ---------------------------------------------------------------------
--  1. TIPE
-- ---------------------------------------------------------------------
--  Dua hal berbeda yang sama-sama disebut "status" dalam percakapan
--  sehari-hari, dan justru karena itu dipisah di sini:
--
--    stok  : keadaan barangnya  -- ada di tangan supplier atau tidak
--    tahap : posisi urusannya   -- sudah sampai mana dengan pelanggan
--
--  Sebuah part bisa "ready" tetapi masih di tahap "tanya", karena
--  pelanggannya belum tentu jadi.
do $tipe$
begin
  if not exists (select 1 from pg_type where typname = 'part_stok') then
    create type part_stok as enum ('ready', 'kosong');
  end if;

  if not exists (select 1 from pg_type where typname = 'part_tahap') then
    -- 'batal' wajib ada. Tanya harga yang tidak berlanjut adalah kejadian
    -- yang paling sering, bukan pengecualian; tanpa cara menutupnya,
    -- daftarnya penuh baris mati dalam dua bulan dan berhenti dibuka.
    create type part_tahap as enum
      ('tanya', 'dipesan', 'dipasang', 'selesai', 'batal');
  end if;
end
$tipe$;


-- ---------------------------------------------------------------------
--  2. TABEL UTAMA
--
--     Satu tabel, bukan dua. "Tanya harga" dan "pemesanan part" adalah
--     dua layar atas baris yang sama pada tahap yang berbeda -- bukan dua
--     kumpulan data. Menyalinnya ke tabel kedua saat pelanggan membayar
--     DP akan mengulang persis cacat yang baru dibereskan bulan ini:
--     nama diperbaiki di satu tempat, yang di tempat lain tetap salah.
-- ---------------------------------------------------------------------
create table if not exists part_orders (
  id            uuid primary key default gen_random_uuid(),
  tanggal       timestamptz not null default now(),

  -- Salinan, bukan sekadar tautan -- alasannya sama dengan nota servis:
  -- harga yang sudah ditawarkan harus tetap bisa ditelusuri atas nama
  -- siapa ia ditawarkan, walau data pelanggannya dikoreksi kemudian.
  customer_nama text        not null,
  customer_telp text,
  customer_id   uuid        references customers(id) on delete set null,

  -- Unit yang partnya dicari.
  barang_type   text,
  barang_sn     text,

  part_req      text        not null,

  -- OEM / ORI. Sengaja teks bebas tanpa check: suatu saat akan ada
  -- "copy" atau "cabutan", dan menambah pilihan di dropdown jauh lebih
  -- murah daripada migrasi hanya untuk satu kata baru.
  keterangan    text,

  teknisi_id    uuid        references profiles(id),
  stok          part_stok,
  tahap         part_tahap  not null default 'tanya',

  -- Harga jual ke pelanggan. Boleh kosong selama partnya masih dicari;
  -- itulah keadaan normal sebuah baris yang baru dibuat.
  harga         numeric(12,2) check (harga >= 0),
  dp            numeric(12,2) not null default 0 check (dp >= 0),

  -- Dihitung server, bukan aplikasi. Sisa tagihan muncul di dua layar,
  -- di laporan, dan nanti di struk -- satu-satunya cara memastikan
  -- semuanya menyebut angka yang sama adalah tidak pernah menghitungnya
  -- lebih dari sekali.
  sisa          numeric(12,2)
                generated always as (coalesce(harga, 0) - dp) stored,

  -- Kapan penjualannya benar-benar tuntas. Inilah yang menentukan sebuah
  -- pesanan masuk laporan bulan yang mana -- bukan tanggal orangnya
  -- bertanya, karena yang bertanya akhir Maret sering baru selesai April.
  tanggal_selesai date,

  -- Nota servis untuk jasa pasangnya, bila ada. Uang jasa tidak dicatat
  -- di tabel ini sama sekali: ia hidup di nota, ikut omset, dan ikut bagi
  -- hasil. Yang ada di sini hanya barangnya.
  service_order_id uuid     references service_orders(id) on delete set null,

  catatan       text,

  created_by    uuid        not null references profiles(id) default auth.uid(),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),

  -- DP atas harga yang belum ada adalah uang yang tidak bisa
  -- dipertanggungjawabkan: sisanya tak terhitung, dan pelanggan tidak
  -- punya angka untuk dipegang.
  constraint dp_perlu_harga
    check (dp = 0 or harga is not null),

  -- Pesanan tidak boleh berjalan tanpa harga yang disepakati.
  constraint pesanan_perlu_harga
    check (tahap in ('tanya', 'batal') or harga is not null)
);

create index if not exists po_tanggal  on part_orders (tanggal desc);
create index if not exists po_tahap    on part_orders (tahap);
create index if not exists po_teknisi  on part_orders (teknisi_id);
create index if not exists po_selesai  on part_orders (tanggal_selesai);
create index if not exists po_customer on part_orders (customer_id);
create index if not exists po_nota     on part_orders (service_order_id);


-- ---------------------------------------------------------------------
--  3. MODAL DAN MARGIN -- TABEL TERPISAH
--
--     HPP hanya boleh dilihat admin. Itu keputusan pemilik toko, dan
--     menegakkannya di aplikasi saja tidak cukup: siapa pun yang punya
--     akun bisa memanggil API-nya langsung tanpa lewat layar mana pun.
--
--     Row Level Security bekerja per-baris, bukan per-kolom, jadi kolom
--     yang harus dirahasiakan tidak bisa dilindungi selama ia duduk di
--     tabel yang sama. Memindahkannya ke tabel sendiri mengubah persoalan
--     kolom menjadi persoalan baris -- dan baris justru yang bisa dijaga
--     RLS.
--
--     Bagi teknisi tabel ini selalu kosong. Aplikasi memperlakukan itu
--     sebagai "tidak berhak melihat", bukan "belum diisi".
-- ---------------------------------------------------------------------
create table if not exists part_order_costs (
  part_order_id uuid primary key
                  references part_orders(id) on delete cascade,

  hpp           numeric(12,2) check (hpp >= 0),

  -- Persentase yang diambil toko di atas modal. Disimpan apa adanya, dan
  -- bukan cuma hasil kalinya: dua bulan kemudian yang perlu dijawab bukan
  -- "berapa harganya" melainkan "waktu itu ambil berapa persen".
  up_persen     numeric(5,2)  check (up_persen >= 0),

  updated_at    timestamptz not null default now(),
  updated_by    uuid references profiles(id)
);


-- ---------------------------------------------------------------------
--  4. PENGATURAN
--
--     Pilihan persentase ditaruh di sini, bukan dikunci di kode. Angka
--     yang mengikuti keadaan pasar harus bisa diubah sendiri oleh yang
--     menjaga toko, saat itu juga -- bukan menunggu aplikasi dibangun
--     ulang.
-- ---------------------------------------------------------------------
create table if not exists part_settings (
  id              smallint primary key default 1 check (id = 1),

  up_toko_pilihan numeric(5,2)[] not null default array[10, 15, 20]::numeric(5,2)[],
  up_toko_bawaan  numeric(5,2)   not null default 10
                    check (up_toko_bawaan >= 0),

  updated_at      timestamptz not null default now(),
  updated_by      uuid references profiles(id)
);

insert into part_settings (id) values (1) on conflict (id) do nothing;


-- ---------------------------------------------------------------------
--  5. TRIGGER
-- ---------------------------------------------------------------------

-- 5a. Tanggal selesai diisi server saat tahapnya tuntas.
--
--     Sengaja tidak dikirim aplikasi. Jam perangkat bisa salah, dan
--     tanggal inilah yang menentukan sebuah penjualan masuk laporan bulan
--     yang mana. Zona waktunya dipatok Asia/Jakarta, sama seperti nota
--     servis, supaya penjualan jam sembilan malam tidak tercatat besok.
create or replace function isi_tanggal_selesai_part()
returns trigger
language plpgsql security definer set search_path = public as $fn$
begin
  if new.tahap = 'selesai' and new.tanggal_selesai is null then
    new.tanggal_selesai := (now() at time zone 'Asia/Jakarta')::date;
  end if;

  new.updated_at := now();
  return new;
end;
$fn$;

drop trigger if exists trg_po_sentuh on part_orders;
create trigger trg_po_sentuh
  before insert or update on part_orders
  for each row execute function isi_tanggal_selesai_part();


-- 5b. Batas kolom untuk teknisi.
--
--     Bentuknya mengikuti claims_guard_update() dan
--     service_orders_guard_update(), supaya seluruh aplikasi punya satu
--     aturan yang bisa dijelaskan dengan satu kalimat: teknisi menyentuh
--     pekerjaan, admin memegang uang dan identitas.
--
--     Yang boleh disentuh teknisi: stok, catatan, dan penanda bahwa
--     partnya sudah ia pasang. Itu saja -- karena hanya itu yang benar-
--     benar ia ketahui lebih dulu daripada meja depan.
create or replace function part_orders_guard_update()
returns trigger
language plpgsql security definer set search_path = public as $fn$
begin
  if is_admin() then
    return new;
  end if;

  if (new.id, new.tanggal, new.customer_nama, new.customer_telp,
      new.customer_id, new.barang_type, new.barang_sn, new.part_req,
      new.keterangan, new.teknisi_id, new.harga, new.dp,
      new.tanggal_selesai, new.service_order_id, new.created_by)
     is distinct from
     (old.id, old.tanggal, old.customer_nama, old.customer_telp,
      old.customer_id, old.barang_type, old.barang_sn, old.part_req,
      old.keterangan, old.teknisi_id, old.harga, old.dp,
      old.tanggal_selesai, old.service_order_id, old.created_by)
  then
    raise exception 'Teknisi hanya boleh menandai part terpasang dan '
                    'mengisi catatan. Harga, DP, dan data pesanan '
                    'diatur admin.';
  end if;

  -- Satu-satunya perpindahan tahap yang memang diketahui teknisi lebih
  -- dulu: partnya datang, lalu ia yang memasangnya. Membuka DP berarti
  -- menerima uang, dan menutup pesanan berarti menyatakan lunas --
  -- keduanya urusan meja depan.
  if new.tahap is distinct from old.tahap
     and not (old.tahap = 'dipesan' and new.tahap = 'dipasang')
  then
    raise exception 'Teknisi hanya boleh menandai part sudah dipasang. '
                    'Pemesanan, pelunasan, dan pembatalan diatur admin.';
  end if;

  return new;
end;
$fn$;

-- Namanya berawalan 'a_' supaya berjalan sebelum trg_po_sentuh: penolakan
-- harus terjadi lebih dulu, sebelum ada kolom yang terisi otomatis.
drop trigger if exists trg_a_po_guard on part_orders;
create trigger trg_a_po_guard
  before update on part_orders
  for each row execute function part_orders_guard_update();


create or replace function sentuh_part_cost()
returns trigger
language plpgsql security definer set search_path = public as $fn$
begin
  new.updated_at := now();
  new.updated_by := auth.uid();
  return new;
end;
$fn$;

drop trigger if exists trg_pc_sentuh on part_order_costs;
create trigger trg_pc_sentuh
  before insert or update on part_order_costs
  for each row execute function sentuh_part_cost();


-- ---------------------------------------------------------------------
--  6. ATURAN AKSES
-- ---------------------------------------------------------------------
alter table part_orders      enable row level security;
alter table part_order_costs enable row level security;
alter table part_settings    enable row level security;

-- Membaca: seluruh antrean, semua orang yang aktif. Teknisi perlu tahu
-- part mana yang sudah datang dan menunggu dipasang, dan itu tidak bisa
-- dijawab oleh daftar yang hanya memuat barisnya sendiri.
drop policy if exists po_baca on part_orders;
create policy po_baca on part_orders for select to authenticated
  using (is_active_user());

-- Membuat: admin saja. Sebuah baris tanya harga adalah janji harga kepada
-- pelanggan, dan janji itu dibuat di meja depan.
drop policy if exists po_admin_tulis on part_orders;
create policy po_admin_tulis on part_orders for insert to authenticated
  with check (is_admin());

drop policy if exists po_hapus on part_orders;
create policy po_hapus on part_orders for delete to authenticated
  using (is_admin());

-- Mengubah: dibuka lebar di sini, lalu dipersempit trigger di bagian 5b.
-- Batas sebenarnya ada di sana, bukan di baris ini.
drop policy if exists po_ubah on part_orders;
create policy po_ubah on part_orders for update to authenticated
  using (is_active_user()) with check (is_active_user());

-- Modal: admin saja, membaca maupun menulis. Inilah gunanya tabel ini
-- dipisah.
drop policy if exists pc_admin on part_order_costs;
create policy pc_admin on part_order_costs for all to authenticated
  using (is_admin()) with check (is_admin());

-- Pengaturan persentase ikut dirahasiakan: daftar 10/15/20 sendiri sudah
-- memberi tahu berapa lebar margin toko.
drop policy if exists ps_admin on part_settings;
create policy ps_admin on part_settings for all to authenticated
  using (is_admin()) with check (is_admin());


-- ---------------------------------------------------------------------
--  7. REALTIME
--
--     Sama alasannya dengan migrasi 0012, termasuk replica identity full:
--     tanpa itu kabar penghapusan tidak pernah sampai ke perangkat, dan
--     baris yang sudah dibatalkan admin tetap terlihat di HP teknisi.
-- ---------------------------------------------------------------------
do $realtime$
declare
  t text;
begin
  foreach t in array array['part_orders', 'part_order_costs', 'part_settings']
  loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = t
    ) then
      execute format(
        'alter publication supabase_realtime add table public.%I', t);
    end if;

    execute format('alter table public.%I replica identity full', t);
  end loop;
end
$realtime$;
