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

- Status: peran, persetujuan, dan laporan mingguan selesai di versi 2.36.0.
  Migrasi 0065 dan akun super admin sudah terpasang, 1 November 2026.
- Urutan pasang sisanya: aplikasi 2.36.0 di semua perangkat, lalu migrasi 0066
  dan 0067 bersama edge function `create-technician`. Kalau dibalik, tidak ada
  yang bisa mengelola pengguna, karena hanya versi baru yang mengenal super
  admin.
- Nota Diambil dan Batal terkunci. Catatan dan pelunasan nota yang belum lunas
  tetap langsung tersimpan; perubahan lain dari admin menjadi permintaan di
  halaman Persetujuan. Teknisi hanya bisa mengubah catatan dan tidak mengajukan.
- Impor melewati kunci, karena hanya untuk migrasi dari aplikasi lama.
- Admin tetap melihat omset per teknisi dan peringatan omset, supaya tahu siapa
  yang perlu didorong. Halaman Kerja Teknisi tetap milik super admin.
- Laporan mingguan: tab Mingguan di Laporan Servis, Senin sampai Minggu, untuk
  super admin dan admin SC.
- Admin hanya menerima servis, melihat laporan omset bulanan dan laporan
  garansi, dan tetap bisa impor data. Perubahan data krusial, seperti nota yang
  sudah keluar atau sudah diambil, perlu persetujuan super admin.
- Halaman super admin: laporan kerja teknisi (omset per teknisi, omset toko),
  piutang, laporan servis, nota per bulan, laporan harian/mingguan/bulanan,
  kirim partner, rekap dan rekap brand, pendapatan.
- Pengaturan khusus super admin (tidak tampil di admin): pengguna, brand, jenis
  part, fee awal, aturan per brand, bagi hasil, identitas toko, up toko
  penjualan part, cara bayar, hari kerja.
- Perlu diputuskan: nasib role `admin_sc` yang ada sekarang. Pembatasan wajib
  ditegakkan di RLS/RPC, bukan hanya menyembunyikan halaman.

### Tanya harga terikat ke nota servis

- Status: menyala di versi 2.36.2, 11 November 2026.
- Biasanya lahir dari nota: tombol Tanya Harga Part di formulir nota, atau
  centang saat membuat nota baru. Pelanggan, unit, SN, dan teknisi dibawa dari
  nota. Satu nota satu tanya harga.
- Halaman Tanya Harga punya dua tombol: Dari Nota (memilih nota dulu) dan
  Manual (Ctrl+N, tanpa nota) untuk pelanggan yang hanya bertanya harga tanpa
  meninggalkan unit. Tanya harga manual bisa ditautkan ke nota belakangan lewat
  pilihan nota di formulirnya.
- Baris menampilkan nomor nota asalnya, formulirnya punya tombol Buka Nota, dan
  formulir nota menampilkan tahap dan harganya.
- Migrasi 0070 mengimpor 1.110 baris sheet 2026 (berkas SQL utuh, dijalankan
  di SQL Editor). Baris 2025 di sheet yang sama dilewati.
- Harga, HPP, dan up diisi belakangan di halaman Tanya Harga. Biaya nota tetap
  hanya jasa; harga part tidak masuk biaya nota atau omset nota.
- Tabel part_orders di database kosong (0 baris). Komentar lama menyebut 946
  baris arsip; barisnya tidak ada di database ini.
- Migrasi 0071 mengimpor 461 baris sheet Pemesanan Part 2026 (Januari sampai
  November). Pesanan yang tanya harganya sudah ada (dari 0070) naik tahap, bukan
  dibuat dua kali; sisanya ditambahkan baru. Status sheet: CLOSE = selesai,
  ORDERED/STOCK/kosong = dipesan, OK = dipasang, CANCEL = batal. Jumlah DP tidak
  ada di sheet, jadi hanya yang CLOSE memakai DP = harga jual. Tanggal selesai
  yang CLOSE diambil dari tanggal order karena sheet tidak mencatatnya.
- Tidak ada batasan di database yang mewajibkan nota: tanya harga manual memang
  tanpa nota.

### Role gudang

- Status: di versi 2.36.3, 11 November 2026. Migrasi 0072 sudah terpasang.
- Tim gudang membeli part dan memeriksa laporan pemesanan yang dikirim ke
  pusat. Gudang melihat halaman Pemesanan Part beserta HPP, untung, dan No PO,
  dengan saringan bulan dan ekspor Excel format sheet.
- Gudang mengisi data pembelian: HPP, tanggal order, No PO, asal part, catatan.
  Harga jual, DP, tahap, nota, dan up toko tetap milik admin; server menolak
  perubahan itu dari akun gudang.
- Gudang tidak membaca nota servis maupun klaim (kebijakan baca dan tulis
  keduanya ditutup untuk gudang). Super admin ikut memegang Tanya Harga dan
  Pemesanan Part.
- Halaman Pemesanan Part punya kartu kelompok: Semua, Belum Selesai (dipesan
  dan dipasang), Selesai, dan Batal, dengan jumlahnya mengikuti bulan yang
  dipilih. Batal yang sudah bayar DP ikut tampil. Halaman selalu satu bulan
  (periode, seperti PERIODE di sheet lama): bulan terbaru lebih dulu, dengan
  panah dan daftar bulan. Dua ekspor: Excel Tampilan (persis yang terlihat) dan
  Excel Lengkap (bulan itu penuh, satu lembar tiap kelompok). Versi 2.36.5.
- Akun gudang dibuat super admin lewat Pengaturan, Pengguna, Tambah. Fungsi
  tambah pengguna baru ikut dipasang bersama 0066.
- Migrasi 0073 mengimpor HPP dan asal part dari sheet gudang 2026 (459 baris,
  453 cocok dengan pesanan yang sudah ada, 6 baru). Dijalankan di SQL Editor
  setelah 0071.

### Rencana perbaikan keterhubungan data

- Status: rencana, disusun 11 November 2026 dari pemeriksaan database. Belum ada
  yang dikerjakan.
- Temuan: tautan antar tabel utuh (tidak ada yang putus), tetapi isinya belum
  semua nyambung. Angka di bawah dari pemeriksaan 11 November 2026.

**Tahap 0 - keputusan dan bahan dari Budi (tanpa ini tahap 2 dan 3 tertahan)**

1. Fee per klaim untuk tiap brand yang punya klaim: Lenovo, Asus, Acer, Axioo,
   HP, MSI, Canon, DAC. Plus tanggal berlaku. Tanpa fee, Rekap Brand dan
   Pendapatan tidak menghitung apa pun (fee 0 baris, rekap 0 baris, aturan bagi
   hasil per brand 0).
2. Aturan bagi hasil per brand: persen toko, admin, teknisi, dan cara membagi
   ke teknisi.
3. Status nota dan klaim: tetap lepas (hanya diberi tanda bila berbeda), atau
   disamakan lagi?
4. Kirim cabang: apakah nota berstatus Dikirim ke Cabang menjadi satu-satunya
   sumber, dan tabel `shipments` hanya riwayat?
5. Batas Part Kembali: klaim close sebelum tanggal berapa dianggap partnya
   sudah kembali (156 klaim sekarang belum ditandai).
6. Daftar klaim brand lain (Asus, Acer, Axioo, Lenovo, HP, Canon) seperti CSV
   MSI, bila mau data part dan nomor RMA-nya diisi dari register.

**Tahap 1 - perbaikan aman, tanpa keputusan (sekitar setengah hari)**

- 2 nota yang punya klaim tetapi tidak bertanda garansi: tandai garansi.
- 6 klaim close tanpa tanggal tutup: isi dari tanggal nota diambil bila ada
  nota, selebihnya dilaporkan satu per satu.
- 65 pesanan part yang tertaut ke nota batal dan 17 pesanan tanpa HPP: tampilkan
  daftarnya untuk gudang dan admin, tidak diubah otomatis.
- 32 nota diambil berbiaya yang belum tercatat lunas: daftar untuk admin
  (halaman Piutang atau Laporan).
- Skrip dibuat dengan pemeriksaan keadaan awal dan dijalankan sebagai satu
  transaksi, seperti 0068 dan 0069.

**Tahap 2 - Rekap Brand dan Pendapatan (butuh Tahap 0 nomor 1 dan 2)**

- Isi fee dan aturan bagi hasil per brand (lewat Pengaturan, atau skrip bila
  angkanya diberikan).
- Tidak perlu mengisi 546 baris rekap: layar Rekap Brand memakai fee sebagai
  nilai awal, dan baris rekap baru lahir saat nilainya dikoreksi dari surat
  brand.
- Cek hasilnya di satu brand dan satu bulan dengan hitungan manual sebelum
  dipakai melapor.

**Tahap 3 - Part Kembali dan klaim yang lepas dari nota**

- Part Kembali: tandai kembali klaim lama sampai batas yang Budi tentukan.
  Isi data part (jenis dan serial rusak) hanya bila register brandnya ada;
  sekarang 542 dari 546 klaim close tanpa data part, hanya MSI Agustus ke atas
  yang terisi.
- 214 klaim tanpa nota (45 klaim brand sejak Agustus) dan 657 nota bertanda
  garansi tanpa klaim: tautkan dengan aturan seperti 0068 (nama, bulan, teknisi,
  pekerjaan) dengan pratinjau lebih dulu. Yang tidak yakin dibiarkan.
- 27 klaim brand tanpa nomor RMA: cocokkan dengan register.
- 47 klaim close dengan nota belum diambil dan 27 nota diambil dengan klaim
  belum close: keputusan Tahap 0 nomor 3. Bila memilih tanda, tampilkan lencana
  "status beda" di formulir nota dan halaman klaim.

**Tahap 4 - kirim cabang dan partner**

- `shipments` (104) dan nota Dikirim ke Cabang (97) tidak saling menaut. Rencana:
  tambah `service_order_id` pada `shipments`, isi lewat pencocokan (SN, nama,
  tanggal kirim) dengan pratinjau, lalu putuskan sumber tunggal (Tahap 0 nomor 4).
- Kirim Partner: belum ada data. Cukup uji satu nota sampai ke laporannya begitu
  super admin memakainya pertama kali.

**Tahap 5 - pencegahan (sesudah tahap 1-4)**

- Halaman Periksa Data untuk super admin: daftar semua celah di atas dengan
  jumlahnya, bisa diklik ke barisnya. Supaya ketidakcocokan ketahuan sejak
  muncul, bukan setelah ratusan baris.
- Simpan klaim ditolak bila statusnya close tetapi tanggal tutup kosong.
- Tutup nota garansi tanpa klaim dengan peringatan, bukan penolakan, karena
  arsip lama memang begitu.

**Yang masih tertahan dari pekerjaan sebelumnya**

- Pasang 2.36.7 di semua perangkat, lalu `0066`, `0067`, dan fungsi tambah
  pengguna dipasang (kunci admin, persetujuan nota, akun gudang lewat aplikasi).
- 67 tes gagal karena persiapan tes, bukan bug: perbaikan di perawatan.
- 48 nomor urut nota kembar dan 152 klaim yang bertanggal tutup 16 September
  masih menunggu keputusan.

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
