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
