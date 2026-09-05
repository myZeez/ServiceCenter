# Riwayat Rilis

Nomor versi mengikuti berkas installer di `installer/output/`.

## 2.5.0 — 5 September 2026

**Admin tidak lagi muncul di pilihan teknisi.** Yang memegang obeng adalah
teknisi, dan bagi hasil dihitung atas nama merekalah — admin yang ikut
terdaftar di situ hanya bikin kolomnya bisa terisi nama yang salah.

Dua hal sengaja tetap dipertahankan. Nama yang **sudah tercatat** mengerjakan
sebuah unit selalu ikut muncul walau ia admin atau sudah dinonaktifkan:
dropdown yang nilainya tidak ada di antara pilihannya melempar galat, dan
nama yang menghilang dari kolomnya terbaca seperti pekerjaannya ikut
terhapus. Dan laporan tetap membaca nama dari daftar lengkap, jadi nota lama
atas nama admin tidak berubah jadi tanda hubung.

Kalau belum ada satu pun teknisi terdaftar, kolomnya mengatakan itu apa
adanya — bukan menawarkan nama yang tidak boleh dipilih.

**Pilihan part menyebut nama lengkapnya**, dengan kodenya sebagai keterangan
kecil di bawah. Sebelumnya hanya kode: ADPT, BTM_CS, CVR_LCD. Yang memilih
harus hafal, padahal namanya sudah ada di data master sejak awal.

## 2.4.0 — 4 September 2026

**Status nota dan klaim berjalan bersama.** Unit bergaransi punya dua
catatan — nota untuk pelanggan, klaim untuk brand — dan selama ini keduanya
hanya ditautkan sekali saat dibuat, lalu dibiarkan jalan sendiri-sendiri.
Pekerjaan ditutup di halaman Servis, klaimnya tetap tertinggal di "Baru
Masuk", dan tidak ada yang memberi tahu.

Sejak ada Rekap Brand, selisih itu berarti uang: yang masuk rekap hanyalah
klaim berstatus Selesai. Klaim yang tertinggal adalah unit yang tidak pernah
ditagihkan ke brand.

Sekarang keduanya sinkron dua arah, dan yang sudah terlanjur berselisih
dibereskan saat migrasi — dengan notanya sebagai acuan. Klaim yang sudah
Selesai atau Batal sengaja tidak disentuh: menarik mundur klaim yang sudah
ditutup akan mengeluarkannya dari rekap, termasuk yang mungkin sudah
dicocokkan dengan surat brand.

Nota **Sudah Diambil** tidak pernah ditarik mundur jadi **Selesai** oleh
arah sebaliknya. Klaim tidak pernah tahu apakah pelanggan sudah mengambil
unitnya.

**Daftar pilihan part menyebut namanya.** Sebelumnya hanya kodenya — ADPT,
FRM_LCD, CVR_LCD — dan yang memilih harus hafal, padahal namanya sudah ada
di data master. Sekarang daftarnya berbunyi "ADPT — Adaptor"; kolomnya
sendiri tetap ringkas dengan kodenya saja, karena sesudah terpilih nama
panjang tidak muat.

## 2.3.0 — 4 September 2026

**Rekap Brand.** Halaman baru untuk mencocokkan unit selesai dengan rekap
bulanan yang dikirim brand, disaring per bulan dan per brand.

Sebabnya: brand membayar berbeda-beda tiap unit, tergantung part dan
pekerjaannya. Satu fee per brand di Pengaturan tidak pernah bisa jadi angka
akhir — ia hanya perkiraan sampai suratnya datang. Angka itu tetap ada,
tetapi turun perannya menjadi nilai awal, dan yang berbeda dikoreksi per
nomor perbaikan.

Bulan rekapnya diambil dari tanggal klaim ditutup, bukan tanggal unitnya
datang: unit yang masuk akhir Maret sering baru tuntas di April, dan brand
membayarnya di rekap April. Klaim lama yang sudah selesai diisi tanggalnya
dari waktu perubahan terakhir — perkiraan, tetapi lebih baik daripada
hilang sama sekali dari rekap.

Bagi hasil kini memakai angka dari surat brand untuk unit yang sudah
dicocokkan, dan nilai awal untuk yang belum. Nol dibedakan dari kosong:
brand kadang menolak sebuah unit, dan itu keterangan yang berbeda dari
belum ada kabar.

## 1.4.0 — 2 September 2026

**Ekspor Excel** untuk ketiga laporan servis, masing-masing berkas sendiri.

Memakai `.xlsx` sungguhan, bukan CSV: biaya ditulis sebagai bilangan sehingga
langsung bisa dijumlahkan di Excel. Pada laporan keseluruhan, biaya, cara
bayar, dan tanggal lunas dipisah menjadi tiga kolom — digabung dalam satu sel,
angkanya tidak bisa dijumlahkan dan penyaringan piutang harus dilakukan dengan
mata.

Jalur berkas ditampilkan setelah tersimpan, karena dialog simpan Windows
sering mengarah ke folder terakhir yang dipakai.

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
