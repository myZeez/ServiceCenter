# SC Management — Service Claim Garansi Cellcom PLK

Aplikasi pencatatan klaim garansi untuk Windows dan Android, menggantikan
pencatatan manual di Google Sheets.

```
supabase/migrations/   skema database (dijalankan di Supabase SQL Editor)
supabase/functions/    Edge Function (dijalankan di server Supabase)
app/                   aplikasi Flutter
```

## Cara kerjanya

Aplikasi **tidak pernah** membaca atau menulis langsung ke Supabase. Semua
operasi lewat database SQLite di perangkat, lalu disinkronkan di latar
belakang. Inilah yang bikin app tetap jalan waktu sinyal hilang.

```
Teknisi input  →  SQLite lokal  →  antre  →  Supabase (Postgres)
                  ↑ sumber data
                    untuk tampilan
```

Konsekuensinya: klaim yang diinput saat offline tercatat dengan **jam saat
diinput**, bukan jam saat akhirnya terkirim.

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
2. **SQL Editor** → jalankan migrasi berurutan:
   - `supabase/migrations/0001_init.sql`
   - `supabase/migrations/0002_active_user_guard.sql`
   - `supabase/migrations/0003_bagi_hasil.sql`
   - `supabase/migrations/0004_bagi_hasil_per_brand.sql`
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

File di `lib/core/local/database.dart` adalah cerminan lokal dari tabel
Postgres. Kalau salah satunya berubah, yang lain harus ikut, lalu:

```bash
cd app
dart run build_runner build
```

Naikkan juga `schemaVersion` di `AppDatabase` dan tambahkan migrasi drift,
supaya data di perangkat yang sudah terpasang tidak hilang.

## Belum dikerjakan

- Impor data lama dari 8 tab spreadsheet
- Fee berbeda per tipe produk (Zenbook, Vivobook) dan per jenis part
- Ganti password sendiri dari dalam aplikasi
- Ekspor rekap ke Excel/PDF

## Bagi hasil

Fee dicatat **per brand dengan tanggal berlaku**, bukan satu angka yang
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
murni, dan dijaga 20 tes. Sengaja tidak ada salinan versi SQL: dua
implementasi rumus yang sama pasti berbeda suatu saat, dan selisihnya baru
ketahuan setelah dibayarkan.

Angka fee, aturan pembagian, dan seluruh perhitungan hanya bisa dibaca admin
— ditegakkan di database, bukan hanya disembunyikan di aplikasi.
