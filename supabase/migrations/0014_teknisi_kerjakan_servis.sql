-- =====================================================================
--  Migrasi 0014 : teknisi boleh mengerjakan nota servis
--
--  Klaim garansi dan nota servis selama ini diperlakukan sangat berbeda,
--  tanpa alasan yang bisa dijelaskan kepada orang yang memakainya:
--
--    klaim   : semua user aktif boleh membaca, dan boleh mengganti kolom
--              teknisi -- kolom lain ditahan trigger
--    servis  : hanya admin yang boleh membaca dan menulis
--
--  Akibatnya teknisi yang mengerjakan sebuah unit tidak bisa menandai
--  pekerjaannya selesai. Yang menerima unit di depan memang admin, tetapi
--  yang tahu kapan unitnya rampung adalah teknisinya.
--
--  Migrasi ini menyamakan keduanya, dengan pembagian yang sama: teknisi
--  menyentuh kolom pekerjaan, admin memegang uang dan identitas nota.
--
--  Aman dijalankan ulang.
-- =====================================================================

-- ---------------------------------------------------------------------
--  1. Membaca: seluruh antrean, bukan hanya notanya sendiri
-- ---------------------------------------------------------------------
--  Kebijakan lama hanya membuka baris yang teknisi_id-nya dirinya sendiri.
--  Itu terlalu sempit untuk dipakai bekerja: teknisi perlu melihat antrean
--  untuk tahu apa yang berikutnya, dan perlu melihat unit rekannya saat
--  menggantikan yang tidak masuk.
drop policy if exists so_teknisi_baca on service_orders;
create policy so_baca on service_orders for select to authenticated
  using (is_active_user());

-- ---------------------------------------------------------------------
--  2. Mengubah: hanya kolom pekerjaan
-- ---------------------------------------------------------------------
--  Kebijakan admin yang sudah ada tetap berlaku penuh dan tidak disentuh.
--  Yang ini menambahkan jalan yang jauh lebih sempit di sebelahnya; batas
--  sebenarnya ditegakkan trigger di bawah, bukan di sini.
drop policy if exists so_teknisi_ubah on service_orders;
create policy so_teknisi_ubah on service_orders for update to authenticated
  using (is_active_user()) with check (is_active_user());

-- ---------------------------------------------------------------------
--  3. Batas kolomnya
-- ---------------------------------------------------------------------
--  Bentuknya mengikuti claims_guard_update() persis, supaya kedua bagian
--  aplikasi punya aturan yang sama dan bisa dijelaskan dengan satu
--  kalimat: teknisi mengubah pekerjaan, admin mengubah uang dan identitas.
--
--  Yang boleh disentuh teknisi: status, perbaikan, teknisi_id, keluhan,
--  kelengkapan, dan keterangan -- semuanya catatan tentang unitnya.
--
--  Yang ditahan: biaya, cara_bayar, tanggal_lunas, no_nota, identitas
--  pelanggan, dan tautan ke klaim garansi. Uang dan nomor nota adalah
--  urusan meja depan, dan nota yang sudah tercetak tidak boleh berubah
--  isinya dari belakang.
create or replace function service_orders_guard_update()
returns trigger
language plpgsql security definer set search_path = public as $fn$
begin
  if not is_admin() then
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

-- Dijalankan sebelum sentuh_service_order() supaya penolakannya terjadi
-- lebih dulu, sebelum ada kolom yang diisi otomatis. Urutan trigger dengan
-- waktu yang sama ditentukan menurut namanya, dan 'a_' memastikan yang ini
-- di depan.
drop trigger if exists trg_a_so_guard on service_orders;
create trigger trg_a_so_guard
  before update on service_orders
  for each row execute function service_orders_guard_update();
