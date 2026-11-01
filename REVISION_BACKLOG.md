# Catatan Revisi Aplikasi

Daftar ini menampung keluhan operasional dan ide perbaikan sebelum
dikerjakan. Supabase tetap sumber data utama; jangan mengubah data produksi
atau membuat rilis hanya berdasarkan catatan di sini tanpa verifikasi.

## Menunggu dikerjakan

### Pengiriman data tahan gangguan koneksi

- Status: ditahan atas permintaan pengguna.
- Masalah: penyimpanan nota bergantung pada satu pengiriman langsung ke
  Supabase. Gangguan koneksi saat mengirim dapat membuat data tidak sampai,
  atau respons gagal diterima meskipun server sebenarnya sudah menyimpan.
- Rencana: tambahkan SQLite lokal hanya sebagai *outbox* sementara, bukan
  database master atau salinan penuh data aplikasi.
- Alur saat normal: `Simpan → Supabase mengonfirmasi → selesai`.
- Alur saat gagal: `Simpan → SQLite outbox → kirim ulang otomatis saat
  koneksi kembali → Supabase mengonfirmasi → hapus dari outbox`.
- Pengaman wajib: gunakan ID permintaan yang tetap agar percobaan ulang tidak
  membuat nota atau nomor nota ganda; tampilkan halaman “Data belum
  terkirim”; hapus item outbox hanya setelah server mengonfirmasi.

### Waktu pengambilan dan pelunasan mengikuti perangkat

- Status: sudah diperbaiki pada 27 September 2026.
- Masalah saat ini: bila waktu pengambilan atau pelunasan tidak dipilih,
  trigger database dapat mengisi waktu server. Lokasi/zona waktu server tidak
  boleh dianggap sama dengan Indonesia, sehingga hari laporan dapat bergeser.
- Perbaikan: aplikasi mengirim tanggal dan jam lokal perangkat saat simpan
  untuk Diambil, Batal, serta pelunasan non-piutang yang belum diberi waktu.
  Server tidak lagi mengganti waktu tersebut dengan `now()`; tanggal dari
  aplikasi dipertahankan, sedangkan turunan dari waktu hanya menjadi
  cadangan untuk klien versi lama.
- Tampilan menjelaskan bahwa waktu otomatis memakai jam perangkat.
- Pengaman: sebelum dipakai, periksa selisih waktu perangkat terhadap waktu
  referensi dan beri peringatan bila selisihnya besar; jangan mengubah waktu
  transaksi yang sudah tercatat tanpa tindakan admin yang jelas.

### Pemisahan role: admin dan super admin

- Status: rencana, dicatat 1 November 2026. Belum dikerjakan.
- Admin hanya menerima servis, melihat laporan omset bulanan dan laporan
  garansi, dan tetap bisa impor data. Perubahan data krusial, seperti nota yang
  sudah keluar atau sudah diambil, perlu persetujuan super admin.
- Halaman super admin: laporan kerja teknisi (omset per teknisi, omset toko),
  piutang, laporan servis, nota per bulan, laporan harian/mingguan/bulanan,
  kirim partner, rekap dan rekap brand, pendapatan.
- Pengaturan khusus super admin (tidak tampil di admin): pengguna, brand, jenis
  part, fee awal, aturan per brand, bagi hasil, identitas toko, up toko
  penjualan part, cara bayar, hari kerja.
- Perlu diputuskan: impor tetap di admin, padahal koreksinya bisa menyentuh
  nota yang sudah keluar; nasib role `admin_sc` yang ada sekarang. Pembatasan
  wajib ditegakkan di RLS/RPC, bukan hanya menyembunyikan halaman.

### Presensi karyawan

- Status: rencana, dicatat 1 November 2026. Belum dikerjakan.
- Dipasang di HP tiap karyawan; role per karyawan: teknisi, sales/marketing,
  gudang, kasir. Teknisi tetap memakai aplikasi seperti sekarang ditambah
  presensi sebagai halaman utama; selain teknisi hanya mendapat tampilan
  presensi.
- Aktif hanya di dalam jangkauan titik koordinat toko (rencana 5 meter) menurut
  GPS realtime; lokasi wajib aktif.
- Isi layar: sapaan pagi/siang/sore/malam dan nama, jam, status Belum Hadir/Hadir,
  status hari ini (hadir, izin, sakit, dinas luar kota, lembur), jarak dari toko,
  pesan tepat waktu atau terlambat sekian menit.
- Tombol: Hadir, Sakit, Izin, Dinas Luar Kota. Hadir aktif hanya di dalam
  jangkauan.
- Perlu diputuskan: 5 meter lebih ketat dari ketelitian GPS HP (umumnya 5-20
  meter, lebih buruk di dalam ruangan), jadi jaraknya perlu bisa diatur di
  Pengaturan dan diuji di toko; jam masuk untuk menghitung terlambat; cara
  mengisi Lembur yang belum punya tombol; tampilan admin di HP dan di Windows.

## Sudah diperbaiki

### Nota keluar tidak muncul karena tanggal pengambilan kosong

- Penyebab: trigger server sebelumnya hanya berjalan saat nota diperbarui,
  bukan saat nota baru dibuat langsung berstatus Diambil/Batal.
- Perbaikan: migrasi `0044` dan koreksi `0045` membatasi cap waktu otomatis
  hanya pada pembuatan nota atau transisi status keluar, serta menghapus cap
  tanggal palsu dari arsip lama.

## Cara menambah keluhan

Catat nama layar/fitur, contoh nomor nota bila ada, kondisi yang memicu,
hasil yang terjadi, dan hasil yang seharusnya. Jangan mencantumkan kata
sandi, API key, atau data sensitif.
