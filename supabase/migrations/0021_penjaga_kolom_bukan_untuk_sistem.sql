-- =====================================================================
--  Migrasi 0021 : penjaga kolom tidak lagi menghalangi sistem sendiri
--
--  Menghapus nota servis gagal dengan pesan yang menuduh orang yang tidak
--  ada di ruangan:
--
--    ERROR: Teknisi hanya boleh mengisi kode part, catatan, dan menandai
--           part terpasang. Harga, DP, dan data pesanan diatur admin.
--    CONTEXT: SQL statement "UPDATE ONLY public.part_orders
--             SET service_order_id = NULL WHERE ..."
--             SQL statement "delete from service_orders"
--
--  Tidak ada teknisi yang menyentuh apa pun. Yang terjadi: part_orders
--  menunjuk ke service_orders dengan "on delete set null", jadi menghapus
--  sebuah nota membuat Postgres SENDIRI menjalankan UPDATE untuk
--  melepaskan tautannya. Update itu melewati trigger penjaga kolom, dan
--  penjaganya bertanya is_admin() -- yang menjawab "bukan" karena tidak
--  ada auth.uid() sama sekali di jalur itu.
--
--  ---------------------------------------------------------------------
--  KENAPA MELONGGARKANNYA AMAN
--  ---------------------------------------------------------------------
--  Dua hal yang berbeda sering tertukar di sini:
--
--    RLS       menentukan SIAPA yang boleh menyentuh sebuah baris
--    penjaga   menentukan KOLOM MANA yang boleh diubah orang itu
--
--  Penjaga ini dibuat untuk membatasi teknisi yang sudah login. Ia bukan
--  lapis keamanan terhadap orang luar -- itu tugas RLS, dan RLS sudah
--  menuntut is_active_user() untuk setiap update. Permintaan tanpa
--  auth.uid() tidak pernah lolos ke sini lewat API.
--
--  Yang benar-benar sampai ke sini tanpa auth.uid() hanya dua:
--    1. Postgres menjaga integritas tautannya sendiri (kasus di atas)
--    2. Sambungan langsung -- SQL Editor, service key -- yang memang
--       sudah melewati RLS menurut rancangannya
--
--  Menghalangi keduanya tidak menambah keamanan sedikit pun. Yang
--  ditambahkannya cuma pesan galat yang menunjuk tersangka yang salah.
--
--  Aman dijalankan ulang.
-- =====================================================================

-- ---------------------------------------------------------------------
--  1. SATU PERTANYAAN, DIPAKAI KETIGA PENJAGA
-- ---------------------------------------------------------------------
--  Dipisah jadi fungsi sendiri supaya ketiga penjaga menanyakan hal yang
--  persis sama. Aturan sehalus ini yang disalin tiga kali pasti berbeda
--  suatu saat, dan bedanya baru ketahuan saat salah satunya menolak
--  sesuatu yang seharusnya lewat.
create or replace function ubah_kolom_bebas()
returns boolean
language sql stable security definer set search_path = public as $fn$
  select auth.uid() is null or is_admin();
$fn$;

comment on function ubah_kolom_bebas() is
  'Benar bila perubahan tidak datang dari pengguna aplikasi yang login '
  '(pemeliharaan sistem, SQL Editor, service key) atau datang dari admin. '
  'Dipakai penjaga kolom, BUKAN untuk RLS -- RLS harus tetap memakai '
  'is_admin() atau is_active_user().';


-- ---------------------------------------------------------------------
--  2. KETIGA PENJAGANYA
-- ---------------------------------------------------------------------
--  Isinya tidak berubah sama sekali selain pertanyaan pembukanya.

create or replace function part_orders_guard_update()
returns trigger
language plpgsql security definer set search_path = public as $fn$
begin
  if ubah_kolom_bebas() then
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


create or replace function service_orders_guard_update()
returns trigger
language plpgsql security definer set search_path = public as $fn$
begin
  if not ubah_kolom_bebas() then
    if (new.no_nota, new.tanggal_masuk, new.customer_nama, new.customer_telp,
        new.customer_id, new.barang_nama, new.barang_type, new.barang_sn,
        new.garansi, new.claim_id, new.biaya, new.cara_bayar,
        new.tanggal_lunas, new.created_by)
       is distinct from
       (old.no_nota, old.tanggal_masuk, old.customer_nama, old.customer_telp,
        old.customer_id, old.barang_nama, old.barang_type, old.barang_sn,
        old.garansi, old.claim_id, old.biaya, old.cara_bayar,
        old.tanggal_lunas, old.created_by)
    then
      raise exception 'Teknisi hanya boleh mengubah status dan catatan '
                      'pekerjaan. Biaya dan data nota diubah admin.';
    end if;
  end if;

  return new;
end;
$fn$;


create or replace function claims_guard_update()
returns trigger
language plpgsql security definer set search_path = public as $fn$
begin
  if not ubah_kolom_bebas() then
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
