# SC Management — Service Claim Garansi Cellcom PLK

Aplikasi pencatatan klaim garansi untuk Windows dan Android, menggantikan
pencatatan manual di Google Sheets.

```
supabase/migrations/   skema database (dijalankan di Supabase SQL Editor)
supabase/functions/    Edge Function (dijalankan di server Supabase)
app/                   aplikasi Flutter
```

## Cara kerjanya

Data hanya tinggal di satu tempat: Supabase. Tiap layar berlangganan
langsung ke tabelnya lewat Realtime, jadi tambah, ubah, dan hapus sampai ke
semua perangkat dalam hitungan detik.

```
Input  →  Supabase (Postgres)  →  Realtime  →  semua layar, semua perangkat
```

**Konsekuensinya jujur: tanpa koneksi, aplikasi tidak bisa dipakai.**

Sebelumnya aplikasi menyimpan cerminannya sendiri di SQLite dan menyalin
isi server tiap beberapa menit, supaya tetap jalan tanpa sinyal. Cerminan
itu dibuang karena tidak pernah bisa membuang baris: sinkronisasinya hanya
menanyakan apa yang berubah, dan baris yang dihapus di server tidak muncul
di jawaban mana pun. Admin menghapus sebuah nota, teknisi masih melihatnya,
dan tidak ada yang bisa menjelaskan mana yang benar. Kemampuan bekerja
tanpa sinyal ditukar dengan satu kenyataan yang sama untuk semua orang.

Dua hal tetap disimpan di perangkat lewat `shared_preferences`, karena
memang tidak punya tempat di database bersama: nama printer dan susunan
kartu di layar.

## Hak akses

Ditegakkan di server lewat Row Level Security dan trigger, jadi tidak bisa
dilewati walaupun seseorang memanggil API-nya langsung tanpa aplikasi.

| | Admin | Teknisi |
|---|---|---|
| Lihat semua klaim | ✅ | ✅ |
| Input klaim baru | ✅ | ✅ |
| Ubah kolom teknisi | ✅ | ✅ |
| Ubah kolom lain | ✅ | ❌ |
| Hapus klaim | ✅ | ❌ |
| Lihat rekap | ✅ | ❌ |
| Cocokkan rekap brand | ✅ | ❌ |
| Kelola pengguna | ✅ | ❌ |

Pengguna yang dinonaktifkan masih bisa login, tetapi tidak melihat data apa
pun dan tidak bisa menulis. Admin terakhir tidak bisa dinonaktifkan atau
diturunkan perannya — dijaga trigger di database, supaya sistem tidak pernah
kehilangan pengelola.

Setiap perpindahan teknisi tercatat di tabel `claim_audit` — siapa yang
mengubah, dari siapa ke siapa, jam berapa. Tidak bisa dihapus lewat API.
Karena nama teknisi menentukan bagi hasil, jejak ini yang jadi dasar
penyelesaian kalau ada perselisihan.

## Menyiapkan database

1. Buat project di [supabase.com](https://supabase.com), region **Southeast Asia (Singapore)**.
2. **SQL Editor** → jalankan seluruh berkas di `supabase/migrations/`
   berurutan menurut nomornya, dari `0001_init.sql` sampai yang terakhir.
   Semuanya aman dijalankan ulang, jadi menjalankan yang sudah pernah
   dijalankan tidak merusak apa pun.
3. **Authentication → Users → Add user**, centang *Auto Confirm User*.
4. Jadikan user itu admin (ganti email dan namanya):

   ```sql
   insert into profiles (id, nama, role)
   select id, 'Nama Kamu', 'admin' from auth.users
   where email = 'email-kamu@perusahaan.com';
   ```

Hanya admin **pertama** yang perlu dibuat lewat dashboard. Selanjutnya
pengguna ditambahkan dari dalam aplikasi.

## Deploy Edge Function

Menambah pengguna butuh `service_role` key, dan kunci itu tidak boleh ada di
dalam aplikasi — siapa pun yang membongkar APK akan bisa menembus seluruh
aturan RLS. Karena itu pembuatan akun dijalankan di server.

Dashboard → **Edge Functions** → **Deploy a new function** → **Via Editor**.
Beri nama persis `create-technician`, lalu tempel isi
`supabase/functions/create-technician/index.ts` dan deploy.

Fungsi ini memeriksa sendiri bahwa pemanggilnya admin yang aktif sebelum
membuat akun, jadi aman walaupun endpoint-nya diketahui orang.

## Menjalankan aplikasi

Salin `app/env.example.json` menjadi `app/env.json`, lalu isi dengan
**Project URL** dan **anon public** key dari *Project Settings → API*.

`env.json` sudah masuk `.gitignore` — jangan pernah di-commit.

```bash
cd app
flutter run -d windows --dart-define-from-file=env.json
```

Android:

```bash
flutter run -d <device-id> --dart-define-from-file=env.json
```

> Jangan pernah memakai **service_role** key di aplikasi. Kunci itu menembus
> semua aturan RLS — kalau APK-nya dibongkar orang, seluruh data terbuka.
> Kunci itu hanya untuk skrip di komputer.

## Build rilis

```bash
flutter build windows --release --dart-define-from-file=env.json
flutter build apk --release --dart-define-from-file=env.json
```

## Kalau skema database diubah

Tiga hal harus ikut berubah:

1. Migrasi baru di `supabase/migrations/`.
2. Model yang bersangkutan di `app/lib/core/data/models.dart` — nama kolom
   di `fromMap` harus persis sama dengan di Postgres.
3. Tabel baru harus didaftarkan ke Realtime. Contohnya ada di migrasi
   `0012_realtime.sql`: masukkan ke publikasi `supabase_realtime` **dan**
   setel `replica identity full`. Tanpa yang kedua, kabar penghapusan
   dibuang diam-diam dan barisnya tetap tampil di layar orang lain.

Salah nama kolom tidak ketahuan saat `flutter analyze`. Penjaganya ada di
`test/models_test.dart` — tambahkan barisnya di situ.

## Impor data lama

Arsip 2026 (1 Januari – 6 September) dibangun ulang dari `DATASET/*.xlsx`
menjadi tiga berkas di `supabase/scripts/`: `migrasi_2026_1.sql` (klaim +
kirim + part), `migrasi_2026_2.sql` (nota Jan–Apr), `migrasi_2026_3.sql`
(nota Mei–Sep) — dipecah supaya ringan di SQL Editor. Kosongkan dulu dengan
`kosongkan_semua.sql`. Generatornya (baca tiap workbook, normalkan,
cocokkan nota↔klaim) ada di `supabase/scripts/gen/` — `npm run build`.
Riwayat sebelum 2026 belum ikut.

## Belum dikerjakan

- Impor riwayat sebelum 2026 (2019–2025)
- Ganti password sendiri dari dalam aplikasi
- Ekspor rekap ke Excel/PDF
- Membaca berkas rekap brand langsung, tanpa mengetik angkanya satu per satu

## Satu unit, dua catatan

Unit bergaransi menghasilkan dua baris sekaligus: **nota** untuk pelanggan
dan **klaim** untuk brand. Lawan bicaranya berbeda, tetapi barangnya satu,
jadi statusnya berjalan bersama — diubah dari nota, klaimnya ikut; diubah
dari klaim, notanya ikut.

| Nota servis | Klaim garansi |
|---|---|
| Masuk | Baru Masuk |
| Dikerjakan | Dikerjakan |
| Tunggu Part | Tunggu Part |
| Selesai | **Selesai** |
| Sudah Diambil | **Selesai** |
| Batal | Batal |

Dua baris terakhir yang tidak sebangun. Bagi brand, pekerjaannya sudah
tuntas begitu unitnya diperbaiki; menunggu pelanggan datang mengambil adalah
urusan meja depan. Karena itu arah baliknya tidak pernah menarik mundur nota
yang sudah **Sudah Diambil** menjadi **Selesai** — klaim tidak pernah tahu
kabar itu.

Padanannya ditulis sekali saja sebagai fungsi di
`0016_status_nota_klaim.sql`, bukan disalin ke Dart. Sebelum ada migrasi itu
keduanya jalan sendiri-sendiri, dan akibatnya bukan cuma membingungkan:
klaim yang tertinggal di "Baru Masuk" tidak pernah masuk rekap bulanan, jadi
tidak pernah ditagihkan ke brand dan tidak pernah ikut dibagi hasilnya.

Teknisi tetap tidak bisa menyentuh status klaim langsung. Yang dibuka hanya
satu jalan: perubahan yang datang dari nota servis, yang memang sudah jadi
haknya sejak `0014_teknisi_kerjakan_servis.sql`.

## Rekap bulanan dari brand

Tiap bulan brand mengirim daftar unit yang sudah tuntas beserta biaya yang
mereka bayar. Besarannya **berbeda-beda tiap unit** — tergantung part dan
pekerjaannya, bukan tergantung mereknya saja — jadi satu angka per brand
tidak pernah bisa jadi angka akhir. Pencocokannya memakai nomor perbaikan
(RMA).

Karena itu nilai sebuah unit punya dua lapis:

| | Dari mana | Kapan dipakai |
|---|---|---|
| Nilai awal | Fee brand di **Pengaturan** | Selama surat brand belum datang |
| Nilai sebenarnya | **Rekap Brand**, per unit | Begitu unitnya dicocokkan |

Lapis pertama sengaja dipertahankan. Tanpanya, tiap unit harus diketik
angkanya walau sebagian besar nilainya sama — dan seluruh klaim yang
terlanjur dibayarkan kehilangan nilainya, membuat rekap kuartal yang sudah
lewat berubah jadi nol.

Halaman **Rekap Brand** memuat unit yang klaimnya sudah Selesai, dikelompokkan
menurut bulan klaim itu ditutup dan bisa disaring per brand. Bulannya diambil
dari `claims.tanggal_close`, bukan dari tanggal unitnya datang: unit yang
masuk akhir Maret sering baru tuntas di April, dan brand membayarnya di rekap
April.

Tanggal itu diisi sekali saja, saat klaimnya pertama kali dinyatakan selesai.
Membuka kembali klaim lama tidak menggesernya — kalau tidak, unit yang
sudah dibayar bulan lalu akan pindah ke rekap bulan berjalan.

Kalau brand ternyata memasukkan sebuah unit ke surat bulan lain, tanggalnya
bisa diubah dari kotak koreksi nilai di halaman itu juga. Klaim yang sudah
selesai sebelum fitur ini ada diisi tanggalnya dari waktu perubahan
terakhirnya — perkiraan, dan justru itu sebabnya harus bisa dibetulkan
tanpa membuka SQL.

Unit tanpa nomor perbaikan ditandai merah di daftar, karena unit semacam itu
tidak bisa dicari di surat brand sama sekali. Nilai nol pun bisa dicatat
apa adanya: brand kadang menolak sebuah unit, dan itu keterangan yang
berbeda dari belum ada kabar.

## Bagi hasil

Fee awal dicatat **per brand dengan tanggal berlaku**, bukan satu angka yang
ditimpa. Kalau fee lama ditimpa, rekap kuartal yang sudah lewat ikut berubah
angkanya — dan pembagian yang terlanjur dibayarkan tidak lagi cocok dengan
laporannya.

Hanya klaim berstatus **Selesai** yang dihitung, karena fee dibayarkan brand
setelah perbaikan tuntas.

**Seluruh perhitungan dilakukan per brand, lalu dijumlahkan.** Tiap brand
membayar fee berbeda dan ditangani susunan tim berbeda, jadi bagian toko,
admin, dan teknisi dihitung dari nilai brand masing-masing — bukan dari satu
angka gabungan. Brand tertentu bisa memakai pembagian sendiri; sisanya
mengikuti aturan umum.

Jatah teknisi tiap brand dibagi dengan salah satu dari tiga metode:

| Metode | Cara kerja |
|---|---|
| **Per unit dikerjakan** | Menurut nilai rupiah yang dihasilkan tiap teknisi di brand itu. Tidak perlu diubah saat jumlah teknisi berubah. |
| Rata | Dibagi sama besar antar yang mengerjakan brand itu |
| Manual per brand | Persentase ditentukan sendiri untuk tiap brand |

Pada metode manual, yang punya porsi tetap dibayar **walau tidak mengerjakan
satu unit pun** — begitulah pekerjaan pendukung seperti input klaim dan
permintaan part memperoleh bagian.

Rumusnya ada di `lib/core/revenue/revenue_calculator.dart` sebagai fungsi
murni, dan dijaga 23 tes. Sengaja tidak ada salinan versi SQL: dua
implementasi rumus yang sama pasti berbeda suatu saat, dan selisihnya baru
ketahuan setelah dibayarkan.

Angka fee, aturan pembagian, dan seluruh perhitungan hanya bisa dibaca admin
— ditegakkan di database, bukan hanya disembunyikan di aplikasi.
