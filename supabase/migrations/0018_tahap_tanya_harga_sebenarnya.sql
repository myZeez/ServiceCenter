-- =====================================================================
--  Migrasi 0018 : tahap tanya harga mengikuti yang benar-benar dipakai
--
--  Migrasi 0017 menebak alurnya dari percakapan. Setelah arsip sheet-nya
--  dibuka, tebakan itu meleset di dua tempat, dan keduanya besar:
--
--  1. Ada dua tahap awal yang sama sekali tidak terpikirkan, dan
--     keduanya ramai:
--
--       Wait Foto/Kode Part  260 baris  -- menunggu teknisi menyebutkan
--                                          kode part persisnya
--       Tunggu Harga           3 baris  -- sudah ditanyakan ke supplier,
--                                          jawabannya belum datang
--
--     Tanpa keduanya, 260 unit menumpuk di satu tahap "tanya" tanpa ada
--     cara membedakan mana yang menunggu teknisi dan mana yang menunggu
--     pelanggan. Itu justru pertanyaan yang ditanyakan tiap pagi.
--
--  2. Kolom "stok" yang dibuat terpisah ternyata tidak pernah dipakai
--     sebagai keterangan barang. Di sheet aslinya "No Stock" adalah
--     STATUS -- jalan buntu, sederajat dengan CANCEL. Tidak ada satu pun
--     baris berstatus "ready": kalau barangnya ada, urusannya langsung
--     jalan terus.
--
--     Jadi dua kolom itu disatukan jadi satu. Satu dropdown, bukan dua --
--     dan itu justru lebih sederhana daripada yang dibuat 0017.
--
--  Ditambahkan juga tiga kolom yang ada di kedua sheet pemesanan dan
--  belum ada di sini: tanggal DP, tanggal order, dan nomor PO.
--
--  Aman dijalankan ulang.
-- =====================================================================

-- ---------------------------------------------------------------------
--  1. TAHAP YANG BARU
-- ---------------------------------------------------------------------
--  Urutannya sengaja mengikuti perjalanan sebuah unit, karena urutan
--  itulah yang dipakai mengurutkan saringan di layar.
--
--  Dua ujung buntu ditaruh di akhir: 'batal' saat pelanggan mundur,
--  'kosong' saat barangnya memang tidak ada. Keduanya berbeda dan
--  keduanya perlu -- yang pertama keputusan pelanggan, yang kedua
--  kegagalan kita mencari barang, dan hanya yang kedua yang layak
--  dihitung sebagai peluang yang hilang.
do $tipe$
begin
  if not exists (select 1 from pg_type where typname = 'part_tahap_v2') then
    create type part_tahap_v2 as enum (
      'foto',        -- Wait Foto/Kode Part
      'harga',       -- Tunggu Harga
      'konfirmasi',  -- Wait Confirm User DP
      'dipesan',     -- Part Dipesan / ORDERED
      'dipasang',    -- Part sudah terpasang, belum lunas
      'selesai',     -- CLOSE = sudah diambil user
      'batal',       -- CANCEL
      'kosong'       -- No Stock
    );
  end if;
end
$tipe$;


-- ---------------------------------------------------------------------
--  2. PINDAHKAN KOLOMNYA
-- ---------------------------------------------------------------------
--  Seluruhnya dijaga keberadaan kolom "stok": selama kolom itu masih
--  ada, migrasinya belum pernah jalan. Sesudah dijalankan sekali, blok
--  ini dilewati begitu saja.
do $pindah$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'part_orders'
      and column_name = 'stok'
  ) then
    return;
  end if;

  -- Constraint yang menyebut tahap harus dilepas dulu; nilainya berubah
  -- arti di tengah jalan.
  alter table part_orders drop constraint if exists pesanan_perlu_harga;

  alter table part_orders alter column tahap drop default;

  -- Baris lama dipetakan menurut apa yang sudah diketahui tentangnya.
  -- Yang tahapnya masih 'tanya' dipilah bertingkat: tidak ada stok jadi
  -- jalan buntu, sudah ada harga berarti tinggal menunggu pelanggan, dan
  -- sisanya menunggu kode part dari teknisi.
  alter table part_orders
    alter column tahap type part_tahap_v2
    using (
      case
        when tahap::text = 'tanya' and stok::text = 'kosong' then 'kosong'
        when tahap::text = 'tanya' and harga is not null     then 'konfirmasi'
        when tahap::text = 'tanya'                           then 'foto'
        else tahap::text
      end
    )::part_tahap_v2;

  alter table part_orders alter column tahap set default 'foto';

  -- Stok tidak lagi punya arti sendiri: seluruh isinya sudah pindah ke
  -- tahap di atas.
  alter table part_orders drop column stok;

  drop type if exists part_stok;
  drop type if exists part_tahap;
  alter type part_tahap_v2 rename to part_tahap;

  -- Dipasang kembali dengan daftar tahap yang baru. 'konfirmasi' ikut
  -- menuntut harga: menunggu pelanggan menyetujui angka yang belum ada
  -- adalah keadaan yang tidak berarti apa-apa.
  alter table part_orders add constraint pesanan_perlu_harga
    check (tahap in ('foto', 'harga', 'batal', 'kosong') or harga is not null);
end
$pindah$;


-- ---------------------------------------------------------------------
--  3. KOLOM DARI SHEET PEMESANAN
-- ---------------------------------------------------------------------
alter table part_orders
  -- Kapan pelanggan membayar mukanya. Di kedua sheet pemesanan inilah
  -- kolom pertama -- yang dipakai mengurutkan dan mengelompokkan per
  -- bulan, bukan tanggal orangnya bertanya.
  add column if not exists tanggal_dp    date,

  -- Kapan partnya benar-benar dipesan ke supplier. Sering berbeda
  -- beberapa hari dari tanggal DP, dan selisih itulah yang ditanyakan
  -- pelanggan saat menunggu.
  add column if not exists tanggal_order date,

  -- Nomor PO ke distributor, atau nama tempat belinya kalau dibeli
  -- lepasan. Dibiarkan satu kolom teks karena di arsipnya memang begitu
  -- dipakai.
  add column if not exists no_po         text;

create index if not exists po_tanggal_dp on part_orders (tanggal_dp);


-- ---------------------------------------------------------------------
--  4. TANGGAL YANG DIISI SENDIRI
-- ---------------------------------------------------------------------
--  Tanggal DP tidak diketik: ia terjadi persis saat tahapnya berpindah
--  ke 'dipesan'. Mengetiknya berarti satu kolom lagi yang bisa lupa
--  diisi, dan seluruh pengelompokan bulanan bergantung padanya.
--
--  Diisi sekali saja. Kalau admin membetulkannya kemudian, koreksi itu
--  tidak ditimpa.
create or replace function isi_tanggal_selesai_part()
returns trigger
language plpgsql security definer set search_path = public as $fn$
begin
  if new.tahap = 'dipesan' and new.tanggal_dp is null then
    new.tanggal_dp := (now() at time zone 'Asia/Jakarta')::date;
  end if;

  if new.tahap = 'selesai' and new.tanggal_selesai is null then
    new.tanggal_selesai := (now() at time zone 'Asia/Jakarta')::date;
  end if;

  new.updated_at := now();
  return new;
end;
$fn$;


-- ---------------------------------------------------------------------
--  5. BATAS KOLOM UNTUK TEKNISI
-- ---------------------------------------------------------------------
--  Diperluas, karena tahap 'foto' menunggu teknisi. Yang ditunggu di 260
--  baris itu adalah kode part persisnya -- dan kode itu hanya ada di
--  tangan orang yang membuka unitnya. Kalau ia tidak boleh mengetiknya,
--  tahap itu tidak akan pernah bisa bergerak dari HP.
--
--  Jadi teknisi boleh menyentuh: part_req, catatan, dan dua perpindahan
--  tahap yang memang ia ketahui lebih dulu daripada meja depan.
--  Harga, DP, PO, tanggal, dan identitas pesanan tetap milik admin.
create or replace function part_orders_guard_update()
returns trigger
language plpgsql security definer set search_path = public as $fn$
begin
  if is_admin() then
    return new;
  end if;

  if (new.id, new.tanggal, new.customer_nama, new.customer_telp,
      new.customer_id, new.barang_type, new.barang_sn, new.keterangan,
      new.teknisi_id, new.harga, new.dp, new.tanggal_dp, new.tanggal_order,
      new.no_po, new.tanggal_selesai, new.service_order_id, new.created_by)
     is distinct from
     (old.id, old.tanggal, old.customer_nama, old.customer_telp,
      old.customer_id, old.barang_type, old.barang_sn, old.keterangan,
      old.teknisi_id, old.harga, old.dp, old.tanggal_dp, old.tanggal_order,
      old.no_po, old.tanggal_selesai, old.service_order_id, old.created_by)
  then
    raise exception 'Teknisi hanya boleh mengisi kode part, catatan, dan '
                    'menandai part terpasang. Harga, DP, dan data pesanan '
                    'diatur admin.';
  end if;

  -- Dua perpindahan, dua sebab:
  --   foto -> harga     : kode partnya sudah ia sebutkan
  --   dipesan -> dipasang : partnya sudah ia pasang
  -- Sisanya menyangkut uang atau keputusan pelanggan.
  if new.tahap is distinct from old.tahap
     and not (old.tahap = 'foto' and new.tahap = 'harga')
     and not (old.tahap = 'dipesan' and new.tahap = 'dipasang')
  then
    raise exception 'Teknisi hanya boleh menandai kode part sudah diisi '
                    'atau part sudah dipasang. Sisanya diatur admin.';
  end if;

  return new;
end;
$fn$;
