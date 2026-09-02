# Riwayat Rilis

Nomor versi mengikuti berkas installer di `installer/output/`.

## 1.3.0 — 2 September 2026

**Laporan servis.** Tiga laporan baru, semuanya di atas data nota dan tidak
menyentuh klaim garansi:

- **Pelunasan** — dikelompokkan per tanggal lunas, dengan subtotal harian dan
  total bulanan. Yang dilaporkan adalah uang yang diterima hari itu, bukan
  unit yang datang; nota bulan lalu yang baru dilunasi bulan ini muncul di
  bulan ini.
- **Keseluruhan** — semua nota bulan berjalan menurut tanggal masuk, menandai
  piutang terpisah dari yang sudah lunas, plus status garansi dan pengambilan.
- **Kirim** — pengiriman antar cabang, lengkap dengan pencatatan dan
  penyuntingannya.

**Sidebar berkelompok** menjadi Pelanggan, Garansi, dan Lainnya. Sebelumnya
semua menu berderet tanpa pembatas, sehingga dua urusan yang lawan bicaranya
berbeda tampak seperti satu rangkaian.

Data locale Indonesia dimuat saat aplikasi mulai; tanpa itu nama hari dan
bulan pada laporan melempar galat.

## 1.2.0 — 2 September 2026

Lebar cetak turun dari 40 ke **32 karakter**. Hasil cetak pertama menunjukkan
40 kelewat lebar untuk kertas 57,5mm: garis pemisah turun ke baris berikutnya
dan nomor nota terbelah.

Nama toko hanya dicetak huruf ganda bila muat separuh kolom; nama panjang
lebih terbaca sebagai satu baris tebal berukuran biasa.

Nomor nota menjadi **`SRV-DDMMYY0001`** dengan angka urut yang berjalan terus
tanpa mengulang. Memakai sequence Postgres, jadi dua penyimpanan bersamaan
tidak pernah mendapat nomor sama.

## 1.1.0 — 2 September 2026

**Cetak nota** lewat printer impact ESC/POS. Epson M-188D memukul kertas,
itulah sebabnya nota lapis tembus ke karbon di bawahnya — dan itu pula
sebabnya nota dikirim sebagai teks, bukan halaman yang dirasterkan.

Identitas toko dan ketentuan nota bisa diatur tanpa membangun ulang aplikasi.
Nama printer dan lebar kolom disimpan per komputer.

## 1.0.0 — 2 September 2026

Installer pertama. Berisi klaim garansi, bagi hasil, dan administrasi servis
(nota masuk dan keluar).

Runtime Visual C++ ikut dibundel; tanpa itu aplikasi gagal terbuka di PC yang
belum pernah dipasangi redistributable-nya. Dipasang per pengguna sehingga
tidak menuntut hak administrator.
