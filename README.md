# SC Management — Service Claim Garansi Cellcom PLK

Aplikasi pencatatan klaim garansi untuk Windows dan Android, menggantikan
pencatatan manual di Google Sheets.

```
supabase/migrations/   skema database (dijalankan di Supabase SQL Editor)
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

Setiap perpindahan teknisi tercatat di tabel `claim_audit` — siapa yang
mengubah, dari siapa ke siapa, jam berapa. Tidak bisa dihapus lewat API.
Karena nama teknisi menentukan bagi hasil, jejak ini yang jadi dasar
penyelesaian kalau ada perselisihan.

## Menyiapkan database

1. Buat project di [supabase.com](https://supabase.com), region **Southeast Asia (Singapore)**.
2. **SQL Editor** → paste isi `supabase/migrations/0001_init.sql` → Run.
3. **Authentication → Users → Add user**, centang *Auto Confirm User*.
4. Jadikan user itu admin (ganti email dan namanya):

   ```sql
   insert into profiles (id, nama, role)
   select id, 'Nama Kamu', 'admin' from auth.users
   where email = 'email-kamu@perusahaan.com';
   ```

Teknisi ditambahkan dengan cara sama, `'admin'` diganti `'teknisi'`.

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
- Perhitungan bagi hasil (masih di file Excel terpisah)
- Manajemen user dari dalam aplikasi (sekarang lewat dashboard Supabase)
- Ekspor rekap ke Excel/PDF
