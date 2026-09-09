import 'package:flutter/material.dart';

/// Warna yang dinamai menurut tugasnya, bukan menurut rupanya.
///
/// Sebelum ini paletnya bernama `black`, `white`, `grey`. Nama begitu jujur
/// selama cuma ada satu tema, tetapi jadi bohong begitu ada dua: `black`
/// yang dipakai sebagai warna teks harus menjadi terang di mode gelap, dan
/// nama yang menyebut rupanya tidak bisa mengatakan itu.
///
/// Yang disimpan di sini karena itu peran: [teks], [garis], [latar]. Rupanya
/// diputuskan paletnya masing-masing di bawah.
@immutable
class WarnaApp extends ThemeExtension<WarnaApp> {
  const WarnaApp({
    required this.teks,
    required this.teksLembut,
    required this.garis,
    required this.garisHalus,
    required this.garisIsian,
    required this.latar,
    required this.permukaan,
    required this.teredam,
    required this.aksen,
    required this.diAksen,
    required this.bahaya,
    required this.garansi,
  });

  /// Teks utama dan elemen yang paling ditekankan.
  final Color teks;

  /// Teks kedua: kaption, satuan, keterangan di bawah kolom.
  final Color teksLembut;

  /// Garis tabel dan bingkai yang memang harus terlihat.
  final Color garis;

  /// Garis rambut: bingkai kartu dan pemisah antar baris.
  ///
  /// Terpisah dari [garis] karena mode terang memang memakai tiga
  /// ketebalan abu yang berbeda, dan menyamakannya di sini berarti
  /// mengubah tampilan siang hari -- yang justru tidak ingin diubah.
  final Color garisHalus;

  /// Bingkai kolom isian saat tidak sedang disorot.
  final Color garisIsian;

  /// Latar halaman.
  final Color latar;

  /// Latar kartu dan dialog, satu tingkat di atas [latar].
  final Color permukaan;

  /// Latar teredam: kepala tabel, bidang yang tidak bisa diisi, batang
  /// kosong pada grafik.
  final Color teredam;

  /// Warna sesuatu yang bisa diklik atau sedang aktif.
  final Color aksen;

  /// Warna teks di atas [aksen].
  final Color diAksen;

  /// Perlu perhatian: piutang, nota batal, tombol hapus, galat.
  final Color bahaya;

  /// Unit bergaransi dan nota lunas.
  ///
  /// Punya namanya sendiri, bukan "sukses". Di toko ini hijau tidak berarti
  /// "berhasil" -- ia berarti "tidak ditagih ke pelanggan", dan itu arti
  /// yang sama dipakai di laporan cetak.
  final Color garansi;

  @override
  WarnaApp copyWith({
    Color? teks,
    Color? teksLembut,
    Color? garis,
    Color? garisHalus,
    Color? garisIsian,
    Color? latar,
    Color? permukaan,
    Color? teredam,
    Color? aksen,
    Color? diAksen,
    Color? bahaya,
    Color? garansi,
  }) => WarnaApp(
    teks: teks ?? this.teks,
    teksLembut: teksLembut ?? this.teksLembut,
    garis: garis ?? this.garis,
    garisHalus: garisHalus ?? this.garisHalus,
    garisIsian: garisIsian ?? this.garisIsian,
    latar: latar ?? this.latar,
    permukaan: permukaan ?? this.permukaan,
    teredam: teredam ?? this.teredam,
    aksen: aksen ?? this.aksen,
    diAksen: diAksen ?? this.diAksen,
    bahaya: bahaya ?? this.bahaya,
    garansi: garansi ?? this.garansi,
  );

  @override
  WarnaApp lerp(covariant WarnaApp? lain, double t) {
    if (lain == null) return this;
    return WarnaApp(
      teks: Color.lerp(teks, lain.teks, t)!,
      teksLembut: Color.lerp(teksLembut, lain.teksLembut, t)!,
      garis: Color.lerp(garis, lain.garis, t)!,
      garisHalus: Color.lerp(garisHalus, lain.garisHalus, t)!,
      garisIsian: Color.lerp(garisIsian, lain.garisIsian, t)!,
      latar: Color.lerp(latar, lain.latar, t)!,
      permukaan: Color.lerp(permukaan, lain.permukaan, t)!,
      teredam: Color.lerp(teredam, lain.teredam, t)!,
      aksen: Color.lerp(aksen, lain.aksen, t)!,
      diAksen: Color.lerp(diAksen, lain.diAksen, t)!,
      bahaya: Color.lerp(bahaya, lain.bahaya, t)!,
      garansi: Color.lerp(garansi, lain.garansi, t)!,
    );
  }

  // -------------------------------------------------------------------
  // Terang -- Swiss/International Typographic Style
  // -------------------------------------------------------------------
  //  Tidak diubah sedikit pun dari yang selama ini dipakai. Siang hari
  //  letak dan warna semuanya sudah hafal di luar kepala, dan tidak ada
  //  yang didapat dari mengubah itu.
  //
  //  Hitamnya sengaja bukan #000000: hitam murni terasa keras di layar
  //  dan menghilangkan kesan tinta di atas kertas.
  static const terang = WarnaApp(
    teks: Color(0xFF1A1A1A),
    teksLembut: Color(0xFFA9B2B1),
    garis: Color(0xFFA9B2B1),
    garisHalus: Color(0xFFE4E7E7),
    garisIsian: Color(0xFFCFD5D4),
    latar: Color(0xFFFFFFFF),
    permukaan: Color(0xFFFFFFFF),
    teredam: Color(0xFFF2F2F2),
    aksen: Color(0xFF0033A0),
    diAksen: Color(0xFFFFFFFF),
    bahaya: Color(0xFFD82C2C),
    garansi: Color(0xFF1B8A4B),
  );

  // -------------------------------------------------------------------
  // Gelap -- Blueprint
  // -------------------------------------------------------------------
  //  Cetak biru: garis terang di atas biru tua. Bentuk itu lahir bukan
  //  karena bagus melainkan karena murah diperbanyak, dan justru itu yang
  //  membuatnya cocok di sini -- yang dibaca gambarnya, bukan hiasannya.
  //
  //  Merahnya dinaikkan dari #D82C2C. Merah pekat yang bagus di atas
  //  kertas putih berubah jadi gumpalan gelap di atas biru tua, dan yang
  //  hilang justru warna yang paling perlu terlihat.
  static const gelap = WarnaApp(
    teks: Color(0xFFF0F0F0),
    teksLembut: Color(0xFF8B9BB4),
    garis: Color(0xFF1C2B3A),
    garisHalus: Color(0xFF1C2B3A),
    garisIsian: Color(0xFF26384A),
    latar: Color(0xFF0B1623),
    permukaan: Color(0xFF12202F),
    teredam: Color(0xFF1C2B3A),
    aksen: Color(0xFFFF9F30),
    diAksen: Color(0xFF0B1623),
    bahaya: Color(0xFFFF5C5C),
    garansi: Color(0xFF00FF9D),
  );
}

/// Jalan pintas ke palet yang sedang berlaku.
///
/// `context.warna.teks` alih-alih `Theme.of(context).extension<WarnaApp>()!`
/// -- yang kedua terlalu panjang untuk ditulis empat ratus kali, dan yang
/// panjang selalu berakhir jadi warna mentah yang ditulis langsung.
extension WarnaKonteks on BuildContext {
  WarnaApp get warna =>
      Theme.of(this).extension<WarnaApp>() ?? WarnaApp.terang;
}
