-- =====================================================================
--  Migrasi 0022 : sebuah nota bisa dinyatakan bergaransi belakangan
--
--  Urutan sebenarnya di toko tidak seperti yang diasumsikan aplikasi.
--  Aplikasi menganggap status garansi sudah diketahui saat unit diterima,
--  jadi centangnya mati begitu notanya tersimpan. Kenyataannya:
--
--    unit masuk  ->  dicatat sebagai servis biasa
--    dibongkar   ->  teknisi melihat unitnya masih bergaransi
--    baru        ->  perlu dibuatkan klaim ke brand
--
--  Dan yang menemukannya adalah teknisi, dari HP-nya, bukan admin di
--  meja depan. Sementara penjaga kolom sejak 0014 justru menutup rapat
--  dua kolom yang persis dibutuhkan di detik itu: garansi dan claim_id.
--
--  ---------------------------------------------------------------------
--  YANG DILAKUKAN
--  ---------------------------------------------------------------------
--  Bukan melonggarkan penjaganya. Kolom itu tetap tertutup bagi update
--  biasa dari teknisi -- yang dibuka satu jalan sempit: fungsi
--  tautkan_nota_ke_klaim(), yang tidak bisa mengubah kolom lain apa pun
--  karena memang tidak menyebutkannya.
--
--  Bentuknya meniru app.sinkron_status di migrasi 0016, dengan alasan
--  yang sama: penandanya berumur satu transaksi dan hanya bisa dipasang
--  dari dalam fungsi di bawah. Lewat API tidak ada cara menyalakannya --
--  PostgREST hanya membuka fungsi di skema public, sedangkan set_config
--  tinggal di pg_catalog.
--
--  Aman dijalankan ulang.
-- =====================================================================

-- ---------------------------------------------------------------------
--  1. PENJAGA KOLOM NOTA, DENGAN SATU PINTU
-- ---------------------------------------------------------------------
--  Isinya sama seperti 0021 kecuali garansi dan claim_id, yang sekarang
--  diperiksa terpisah. Dipisah supaya pesan galatnya bisa menyebutkan
--  jalan yang benar, alih-alih menuduh teknisi menyentuh uang.
create or replace function service_orders_guard_update()
returns trigger
language plpgsql security definer set search_path = public as $fn$
declare
  menaut boolean :=
    coalesce(current_setting('app.taut_klaim', true), 'off') = 'on';
begin
  if not ubah_kolom_bebas() then
    if (new.no_nota, new.tanggal_masuk, new.customer_nama, new.customer_telp,
        new.customer_id, new.barang_nama, new.barang_type, new.barang_sn,
        new.biaya, new.cara_bayar, new.tanggal_lunas, new.created_by)
       is distinct from
       (old.no_nota, old.tanggal_masuk, old.customer_nama, old.customer_telp,
        old.customer_id, old.barang_nama, old.barang_type, old.barang_sn,
        old.biaya, old.cara_bayar, old.tanggal_lunas, old.created_by)
    then
      raise exception 'Teknisi hanya boleh mengubah status dan catatan '
                      'pekerjaan. Biaya dan data nota diubah admin.';
    end if;

    if not menaut
       and (new.garansi, new.claim_id)
           is distinct from (old.garansi, old.claim_id)
    then
      raise exception 'Tanda garansi pada nota diubah lewat klaimnya, '
                      'bukan dengan menyunting nota.';
    end if;
  end if;

  return new;
end;
$fn$;


-- ---------------------------------------------------------------------
--  2. MENAUTKAN NOTA KE KLAIMNYA
-- ---------------------------------------------------------------------
--  Dua kolom, sekali jalan, dan menolak menimpa tautan yang sudah ada.
--
--  Penolakan itu penting: satu nota yang menunjuk dua klaim akan membuat
--  sinkronisasi status di 0016 tarik-menarik, dan yang kalah adalah unit
--  yang statusnya berubah sendiri tanpa ada yang menyentuhnya. Menaut
--  ulang ke klaim yang SAMA tetap boleh -- itu percobaan kedua atas
--  penyimpanan yang gagal separuh jalan, bukan tautan kedua.
--
--  Mengembalikan nomor notanya supaya aplikasi bisa menyebut nota mana
--  yang ikut berubah. Perubahan yang diam-diam merembet ke layar lain
--  adalah perubahan yang tidak bisa dijelaskan kepada yang menemukannya.
create or replace function tautkan_nota_ke_klaim(p_nota uuid, p_klaim uuid)
returns text
language plpgsql volatile security definer set search_path = public as $fn$
declare
  nota record;
begin
  -- security definer melewati RLS, jadi syarat yang biasanya ditegakkan
  -- kebijakan baris harus ditanyakan sendiri di sini.
  if not is_active_user() then
    raise exception 'Akun ini tidak aktif.';
  end if;

  select id, no_nota, claim_id into nota
  from service_orders where id = p_nota;

  if not found then
    raise exception 'Nota servisnya tidak ditemukan.';
  end if;

  if not exists (select 1 from claims where id = p_klaim) then
    raise exception 'Klaim garansinya tidak ditemukan.';
  end if;

  if nota.claim_id is not null and nota.claim_id <> p_klaim then
    raise exception 'Nota % sudah tertaut ke klaim garansi lain.',
                    nota.no_nota;
  end if;

  perform set_config('app.taut_klaim', 'on', true);

  update service_orders
  set garansi = true, claim_id = p_klaim
  where id = p_nota;

  perform set_config('app.taut_klaim', 'off', true);

  return nota.no_nota;
end;
$fn$;

comment on function tautkan_nota_ke_klaim(uuid, uuid) is
  'Menandai sebuah nota servis bergaransi dan menghubungkannya ke klaim. '
  'Satu-satunya jalan bagi teknisi mengubah garansi dan claim_id; kolom '
  'lain tidak tersentuh. Mengembalikan nomor notanya.';

grant execute on function tautkan_nota_ke_klaim(uuid, uuid) to authenticated;
