-- =====================================================================
--  Migrasi 0026 : penghitung nomor nota ikut maju sendiri
--
--  ---------------------------------------------------------------------
--  KENAPA
--  ---------------------------------------------------------------------
--  Nota yang masuk lewat skrip impor membawa nomornya sendiri dari buku
--  kertas, dan nomor itu tidak pernah lewat nextval. Penghitung di server
--  tetap berdiri di tempat sementara buku terus berjalan, lalu nota
--  berikutnya yang dibuat aplikasi membagikan nomor yang sudah dipakai
--  orang lain.
--
--  Sudah terjadi dua kali. Pertama satu nota (28248), lalu tujuh belas
--  sekaligus: 9 September mulai lagi dari 28249 padahal 28249 sampai
--  28265 sudah dipakai 7 September. Kolom no_nota memang unique, tapi
--  yang dijaganya seluruh teksnya -- SVR-07092628249 dan SRV-09092628249
--  dua teks berbeda, jadi keduanya lolos.
--
--  Keduanya dibereskan dengan tangan, dan angkanya diisi ulang lewat
--  Pengaturan -> Nomor Nota. Itu obat, bukan penutup lubang: setiap
--  impor berikutnya membuka lubang yang sama.
--
--  ---------------------------------------------------------------------
--  YANG DIUBAH
--  ---------------------------------------------------------------------
--  Nota yang membawa nomornya sendiri kini ikut menggerakkan penghitung,
--  kalau nomornya lebih tinggi dari yang akan terbit berikutnya. Nota
--  yang tidak membawa nomor tetap dilayani seperti biasa.
--
--  Penghitungnya hanya boleh maju, tidak pernah mundur. Nota lama yang
--  masuk belakangan -- impor Januari yang dikerjakan bulan September --
--  tidak menarik nomor berikutnya kembali ke masa lalu.
--
--  Hanya admin yang boleh menyisipkan nota (kebijakan so_admin), dan
--  admin memang sudah boleh menggeser penghitung lewat Pengaturan. Jadi
--  ini tidak membuka kewenangan baru bagi siapa pun.
--
--  Aman dijalankan ulang.
-- =====================================================================


-- ---------------------------------------------------------------------
--  Membaca angka urut dari sebuah nomor nota
-- ---------------------------------------------------------------------
--  Bentuknya `SRV-` + DDMMYY + angka urut, jadi angka urutnya mulai dari
--  huruf ke-11. Bukan lima digit terakhir: nomor yang melewati 99999
--  tumbuh jadi enam digit, dan memotong lima dari belakang diam-diam
--  mengubah artinya.
--
--  Awalannya sengaja tidak dipatok `SRV-`. Arsip toko memakai `SVR-`
--  untuk seluruh notanya, dan nota impor itu justru yang paling perlu
--  terbaca di sini.
--
--  Nomor berformat lama (YYMM-NNN dari migrasi 0007) tidak cocok dengan
--  pola ini dan mengembalikan null -- memang tidak boleh menggerakkan
--  penghitung, karena angkanya mengulang tiap bulan.
--  Namanya sengaja bukan `no_nota`: parameter yang senama dengan kolom
--  membuat setiap query di dalam fungsi jadi taruhan tentang yang mana
--  yang dimaksud.
create or replace function urut_no_nota(nomor text)
returns bigint
language sql immutable set search_path = public as $fn$
  select case
           when nomor ~ '^[A-Za-z]{3}-[0-9]{11,}$'
           then substr(nomor, 11)::bigint
         end;
$fn$;


-- ---------------------------------------------------------------------
--  Trigger pengisi nomor nota
-- ---------------------------------------------------------------------
--  setval dipanggil tanpa is_called, jadi nilainya dianggap "sudah
--  terpakai" dan nextval berikutnya memberi satu di atasnya. Itu memang
--  yang benar di sini: nomor yang dibawa nota ini sudah menjadi miliknya.
--
--  Sequence tidak ikut dibatalkan saat transaksi gagal. Untuk penghitung
--  nomor itu sisi yang aman: yang tertinggal hanyalah satu angka yang
--  dilewati, bukan satu angka yang dipakai dua kali.
create or replace function isi_no_nota()
returns trigger
language plpgsql security definer set search_path = public as $fn$
declare
  bawa bigint;
begin
  if new.no_nota is null or new.no_nota = '' then
    new.no_nota := buat_no_nota();
    return new;
  end if;

  bawa := urut_no_nota(new.no_nota);
  if bawa is not null and bawa >= nomor_nota_berikutnya() then
    perform setval('no_nota_seq', bawa);
  end if;

  return new;
end;
$fn$;

drop trigger if exists trg_no_nota on service_orders;
create trigger trg_no_nota
  before insert on service_orders
  for each row execute function isi_no_nota();

-- Penomoran ulang ikut dijaga. Skrip perbaikan 9 September memindahkan
-- tujuh belas nota ke 28276..28292 sementara penghitung masih di 28265,
-- dan angkanya harus diisi dengan tangan lagi sesudahnya. Dengan trigger
-- ini, memperbaiki nomor sudah sekaligus menggerakkan penghitungnya.
--
-- Namanya jatuh sesudah trg_a_so_guard, dan itu memang harus. Penjaga
-- kolom yang menolak perubahan no_nota oleh yang tidak berhak berjalan
-- lebih dulu, jadi penghitung tidak pernah digerakkan oleh perubahan
-- yang sedetik kemudian ditolak.
drop trigger if exists trg_no_nota_ubah on service_orders;
create trigger trg_no_nota_ubah
  before update of no_nota on service_orders
  for each row
  when (new.no_nota is distinct from old.no_nota)
  execute function isi_no_nota();


-- ---------------------------------------------------------------------
--  Menyusul yang sudah terlanjur
-- ---------------------------------------------------------------------
--  Trigger di atas hanya berlaku untuk yang datang sesudah ini. Nota yang
--  sudah ada di tabel tidak pernah melewatinya, jadi penghitungnya
--  disamakan sekali di sini.
--
--  Hanya maju: kalau penghitung sudah berada di atas nomor tertinggi
--  yang terpakai -- misalnya baru saja diisi dari Pengaturan -- angkanya
--  dibiarkan.
do $$
declare
  tertinggi bigint;
begin
  select max(urut_no_nota(no_nota)) into tertinggi from service_orders;

  if tertinggi is not null and tertinggi >= nomor_nota_berikutnya() then
    perform setval('no_nota_seq', tertinggi);
    raise notice 'Penghitung nomor nota disusulkan ke %, berikutnya %',
                 tertinggi, tertinggi + 1;
  else
    raise notice 'Penghitung nomor nota sudah di depan, berikutnya %',
                 nomor_nota_berikutnya();
  end if;
end;
$$;


-- ---------------------------------------------------------------------
--  Memastikan
-- ---------------------------------------------------------------------
--  Harus sama: nomor tertinggi yang terpakai + 1 = nomor berikutnya.

select max(urut_no_nota(no_nota))     as urut_tertinggi,
       max(urut_no_nota(no_nota)) + 1 as seharusnya_berikutnya,
       nomor_nota_berikutnya()        as berikutnya_sekarang
from service_orders;
