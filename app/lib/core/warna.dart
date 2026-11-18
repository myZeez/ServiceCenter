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
    required this.kertas,
    required this.diTeks,
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

  /// Latar halaman. SELALU dipakai sebagai latar, tidak pernah sebagai warna
  /// tulisan -- di mode kaca ia bening sama sekali. Tulisan di atas bidang
  /// berwarna [teks] memakai [diTeks].
  final Color latar;

  /// Latar kartu dan dialog, satu tingkat di atas [latar].
  ///
  /// SELALU dipakai sebagai latar. Di mode kaca ia tembus pandang, jadi
  /// tulisan dan ikon di atas bidang berwarna memakai [kertas] -- warna yang
  /// sama, tetapi padat.
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

  /// Warna [permukaan] yang selalu padat: tulisan dan ikon di atas chip atau
  /// tombol yang berwarna penuh.
  ///
  /// Ada sejak mode kaca. Sebelumnya tugas ini dipegang [permukaan] sendiri,
  /// dan itu baru bermasalah begitu permukaan boleh tembus pandang -- tulisan
  /// putih di atas chip biru ikut pudar menjadi kebiruan.
  final Color kertas;

  /// Warna tulisan di atas bidang berwarna [teks]: tombol utama, snackbar,
  /// chip terpilih. Padat, walau [latar] bening.
  final Color diTeks;

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
    Color? kertas,
    Color? diTeks,
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
    kertas: kertas ?? this.kertas,
    diTeks: diTeks ?? this.diTeks,
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
      kertas: Color.lerp(kertas, lain.kertas, t)!,
      diTeks: Color.lerp(diTeks, lain.diTeks, t)!,
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
    kertas: Color(0xFFFFFFFF),
    diTeks: Color(0xFFFFFFFF),
  );

  // -------------------------------------------------------------------
  // Gelap -- abu arang
  // -------------------------------------------------------------------
  //  Layar kantor yang kalibrasinya kurang baik sering menarik biru tua
  //  menjadi hitam kebiruan yang keruh. Abu arang memberi tingkat bidang
  //  yang lebih mudah dibedakan tanpa mengubah warna bermakna.
  static const gelap = WarnaApp(
    teks: Color(0xFFF0F0F0),
    teksLembut: Color(0xFFA6A6A6),
    garis: Color(0xFF3A3A3A),
    garisHalus: Color(0xFF363636),
    garisIsian: Color(0xFF4A4A4A),
    latar: Color(0xFF171717),
    permukaan: Color(0xFF222222),
    teredam: Color(0xFF2C2C2C),
    aksen: Color(0xFFF0A13A),
    diAksen: Color(0xFF171717),
    bahaya: Color(0xFFFF6B6B),
    garansi: Color(0xFF68D391),
    kertas: Color(0xFF222222),
    diTeks: Color(0xFF171717),
  );

  // -------------------------------------------------------------------
  // Kaca -- khusus Android
  // -------------------------------------------------------------------
  //  Dua palet di atas dengan satu perbedaan: bidang tidak lagi padat.
  //  Latar halaman bening -- yang tampak adalah latar kaca di belakangnya
  //  (lihat LatarKaca) -- dan kartu, kolom isian, serta dialog tembus
  //  pandang. Warna yang membawa arti (aksen, bahaya, garansi) tidak
  //  disentuh, dan tulisan tetap padat.
  //
  //  Garis rambut ikut tembus pandang. Garis abu padat di atas kaca
  //  terbaca sebagai tempelan; garis yang meminjam warna tulisannya
  //  menyatu dengan apa pun yang ada di belakangnya.
  //
  //  Teks lembut di terang digelapkan sedikit: #A9B2B1 di atas kertas putih
  //  sudah pas-pasan, dan di atas latar kaca yang kebiruan ia nyaris hilang.
  static const terangKaca = WarnaApp(
    teks: Color(0xFF1A1A1A),
    teksLembut: Color(0xFF7E8988),
    garis: Color(0xFFA9B2B1),
    garisHalus: Color(0x1A1A1A1A),
    garisIsian: Color(0x331A1A1A),
    latar: Color(0x00FFFFFF),
    permukaan: Color(0x94FFFFFF),
    teredam: Color(0x0F1A1A1A),
    aksen: Color(0xFF0033A0),
    diAksen: Color(0xFFFFFFFF),
    bahaya: Color(0xFFD82C2C),
    garansi: Color(0xFF1B8A4B),
    kertas: Color(0xFFFFFFFF),
    diTeks: Color(0xFFFFFFFF),
  );

  static const gelapKaca = WarnaApp(
    teks: Color(0xFFF0F0F0),
    teksLembut: Color(0xFFB2B2B2),
    garis: Color(0xFF565656),
    garisHalus: Color(0x1FFFFFFF),
    garisIsian: Color(0x33FFFFFF),
    latar: Color(0x00171717),
    permukaan: Color(0xA3222222),
    teredam: Color(0x1AFFFFFF),
    aksen: Color(0xFFF0A13A),
    diAksen: Color(0xFF171717),
    bahaya: Color(0xFFFF6B6B),
    garansi: Color(0xFF68D391),
    kertas: Color(0xFF222222),
    diTeks: Color(0xFF171717),
  );
}

/// Jalan pintas ke palet yang sedang berlaku.
///
/// `context.warna.teks` alih-alih `Theme.of(context).extension<WarnaApp>()!`
/// -- yang kedua terlalu panjang untuk ditulis empat ratus kali, dan yang
/// panjang selalu berakhir jadi warna mentah yang ditulis langsung.
extension WarnaKonteks on BuildContext {
  WarnaApp get warna => Theme.of(this).extension<WarnaApp>() ?? WarnaApp.terang;
}

/// Palet khusus efek Liquid Glass agar seluruh warna tetap terpusat di
/// [warna.dart], terpisah dari palet datar [WarnaApp].
abstract final class WarnaLiquid {
  /// Warna kaca bening bawaan untuk header, dock, dan tombol menu.
  static const tintTerang = Color(0x2EFFFFFF);
  static const tintGelap = Color(0x33202024);

  /// Warna kaca bening untuk tombol ikon navigasi di AppBar (kembali / tutup).
  static const ikonTerang = Color(0x38FFFFFF);
  static const ikonGelap = Color(0x1EFFFFFF);

  /// Kaca bening tetesan kursor Liquid Glass di Windows.
  static const tetesanTerang = Color(0x22FFFFFF);
  static const tetesanGelap = Color(0x28FFFFFF);
}
