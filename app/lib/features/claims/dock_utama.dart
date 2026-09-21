import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/kaca/panel_kaca.dart';
import '../../core/theme.dart';

/// Dua isi halaman utama di layar sempit.
enum TabUtama { klaim, servisku }

/// Dock kapsul di dasar halaman utama: Klaim Garansi di kiri, tombol
/// tambah di tengah, Servisku di kanan.
///
/// Tombol tengah hanya ikon "+", tanpa tulisan -- ia membuka formulir klaim
/// baru, bukan berpindah isi, jadi ia tidak pernah "terpilih". Justru karena
/// tengahnya ramping, kedua sisinya bisa lega dan labelnya terbaca utuh.
///
/// Perpindahannya digerakkan seperti setetes air: tepi yang menuju arah
/// tujuan berangkat lebih dulu, tepi belakangnya menyusul, jadi penandanya
/// merenggang di tengah jalan lalu menyusut kembali. Ikonnya tidak
/// disilangkan dengan ikon lamanya -- silang-ganti meninggalkan bayangan
/// ganda -- melainkan berganti sekaligus sambil memantul sedikit.
class DockUtama extends StatefulWidget {
  const DockUtama({
    super.key,
    required this.tab,
    required this.onTab,
    required this.onKlaimBaru,
    this.jumlahServisku = 0,
  });

  final TabUtama tab;
  final ValueChanged<TabUtama> onTab;
  final VoidCallback onKlaimBaru;

  /// Unit yang sedang dipegang, ditempel di ikon Servisku. Nol tidak
  /// menampilkan apa-apa.
  final int jumlahServisku;

  static const tinggi = 72.0;
  static const jarak = 12.0;
  static const lebarMaks = 320.0;

  /// Lebar tempat tombol tengah: tombolnya bulat 56, sisanya napas di
  /// kiri-kanan supaya penanda tab tidak menempel padanya.
  static const _lebarTengah = 76.0;
  static const _isiPadding = 8.0;

  /// Penanda tab aktif. Bisa dicari dari luar -- pengujian membacanya untuk
  /// memastikan ia benar-benar meluncur dan merenggang, bukan melompat.
  static const kunciPenanda = ValueKey<String>('penanda-dock');

  /// Lama gerakan perpindahan. Nol bila pengguna mematikan animasi di
  /// pengaturan sistemnya.
  static Duration lamaGerak(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 420);

  /// Ruang yang harus disisakan di dasar daftar supaya baris terakhirnya
  /// tidak tertutup dock.
  static double ruangBawah(BuildContext context) =>
      tinggi + jarak * 2 + MediaQuery.paddingOf(context).bottom;

  @override
  State<DockUtama> createState() => _DockUtamaState();
}

class _DockUtamaState extends State<DockUtama>
    with SingleTickerProviderStateMixin {
  late final AnimationController _gerak = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  )..value = 1;

  /// Tepi penanda saat gerakan terakhir dimulai, dan tepinya sekarang.
  /// Yang kedua dicatat tiap frame supaya ketukan yang datang di tengah
  /// jalan berangkat dari tempat penandanya berada, bukan meloncat dulu ke
  /// tempat asalnya.
  double _kiriMulai = 0;
  double _kananMulai = 0;
  double _kiriKini = 0;
  double _kananKini = 0;
  double _sisi = 0;

  /// Tab yang sedang dituju. Disetel di initState, BUKAN sebagai nilai
  /// awal bertanda late: nilai late baru dihitung saat pertama dibaca --
  /// yaitu di dalam didUpdateWidget, ketika widget-nya sudah berisi tab
  /// yang baru. Dock lalu menyimpulkan tidak ada yang berubah, dan
  /// penandanya melompat tanpa animasi.
  late TabUtama _tujuan;

  /// Tepi mana yang berangkat lebih dulu.
  bool _keKanan = true;

  @override
  void initState() {
    super.initState();
    _tujuan = widget.tab;
  }

  @override
  void dispose() {
    _gerak.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(DockUtama lama) {
    super.didUpdateWidget(lama);
    if (widget.tab == _tujuan) return;

    _keKanan = widget.tab.index > _tujuan.index;
    _tujuan = widget.tab;
    _kiriMulai = _kiriKini;
    _kananMulai = _kananKini;
    _gerak.duration = DockUtama.lamaGerak(context);
    _gerak.forward(from: 0);
  }

  // Tepi yang memimpin berangkat lebih dulu dan sampai lebih cepat; tepi
  // yang mengekor berangkat belakangan. Selisih keduanya itulah
  // renggangnya.
  static const _memimpin = Interval(0, 0.72, curve: Curves.easeOutCubic);
  static const _mengekor = Interval(0.24, 1, curve: Curves.easeOutCubic);

  double _kiriSlot(TabUtama t) =>
      t == TabUtama.klaim ? 0 : _sisi + DockUtama._lebarTengah;

  @override
  Widget build(BuildContext context) {
    final w = context.warna;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: DockUtama.lebarMaks),
      child: PanelKaca(
        tingkat: TingkatKaca.sedang,
        radius: BorderRadius.circular(DockUtama.tinggi / 2),
        bayangan: true,
        child: SizedBox(
          height: DockUtama.tinggi,
          child: Padding(
            padding: const EdgeInsets.all(DockUtama._isiPadding),
            child: LayoutBuilder(
              builder: (context, box) {
                _sisi = (box.maxWidth - DockUtama._lebarTengah) / 2;
                final tujuanKiri = _kiriSlot(widget.tab);

                return Stack(
                  children: [
                    AnimatedBuilder(
                      animation: _gerak,
                      builder: (context, _) {
                        final p = _gerak.value;
                        final maju = _memimpin.transform(p);
                        final mundur = _mengekor.transform(p);
                        final kiri = _antara(
                          _kiriMulai,
                          tujuanKiri,
                          _keKanan ? mundur : maju,
                        );
                        final kanan = _antara(
                          _kananMulai,
                          tujuanKiri + _sisi,
                          _keKanan ? maju : mundur,
                        );
                        _kiriKini = kiri;
                        _kananKini = kanan;

                        // Sedikit memipih saat merenggang, seperti tetesan
                        // yang ditarik: lebarnya bertambah, tebalnya
                        // berkurang.
                        final pipih = 3 * math.sin(math.pi * p);

                        return Positioned(
                          left: kiri,
                          width: math.max(0, kanan - kiri),
                          top: pipih,
                          bottom: pipih,
                          child: DecoratedBox(
                            key: DockUtama.kunciPenanda,
                            decoration: ShapeDecoration(
                              shape: const StadiumBorder(),
                              color: w.teks.withValues(alpha: 0.09),
                            ),
                          ),
                        );
                      },
                    ),
                    Row(
                      children: [
                        SizedBox(
                          width: _sisi,
                          child: _ItemDock(
                            label: 'Klaim Garansi',
                            ikon: Icons.verified_user_outlined,
                            ikonAktif: Icons.verified_user,
                            aktif: widget.tab == TabUtama.klaim,
                            onTap: () => _pilih(TabUtama.klaim),
                          ),
                        ),
                        SizedBox(
                          width: DockUtama._lebarTengah,
                          child: _Tambah(onTap: widget.onKlaimBaru),
                        ),
                        SizedBox(
                          width: _sisi,
                          child: _ItemDock(
                            label: 'Servisku',
                            ikon: Icons.build_outlined,
                            ikonAktif: Icons.build,
                            aktif: widget.tab == TabUtama.servisku,
                            lencana: widget.jumlahServisku,
                            onTap: () => _pilih(TabUtama.servisku),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _pilih(TabUtama t) {
    if (t != widget.tab) HapticFeedback.selectionClick();
    widget.onTab(t);
  }
}

/// Serupa lerpDouble dari dart:ui, tetapi tanpa nullable -- dipakai tiap frame.
double _antara(double a, double b, double t) => a + (b - a) * t;

class _ItemDock extends StatelessWidget {
  const _ItemDock({
    required this.label,
    required this.ikon,
    required this.ikonAktif,
    required this.aktif,
    required this.onTap,
    this.lencana = 0,
  });

  final String label;
  final IconData ikon;
  final IconData ikonAktif;
  final bool aktif;
  final VoidCallback onTap;
  final int lencana;

  @override
  Widget build(BuildContext context) {
    final w = context.warna;
    final gerak = DockUtama.lamaGerak(context);

    return Semantics(
      button: true,
      selected: aktif,
      label: label,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: aktif ? 1 : 0),
              duration: gerak,
              // Memantul sedikit melewati ukurannya lalu kembali: yang
              // baru dipilih terasa ditekan masuk, bukan sekadar berganti
              // warna.
              curve: Curves.easeOutBack,
              builder: (context, t, _) {
                // Yang tidak aktif memakai teks utama yang dipudarkan,
                // bukan teksLembut: di siang hari teksLembut terlalu pucat
                // untuk label sekecil ini di atas kaca.
                final warna = Color.lerp(
                  w.teks.withValues(alpha: 0.62),
                  w.teks,
                  t.clamp(0, 1),
                )!;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Transform.scale(
                          scale: 1 + 0.12 * t,
                          child: Icon(
                            aktif ? ikonAktif : ikon,
                            size: 24,
                            color: warna,
                          ),
                        ),
                        if (lencana > 0)
                          Positioned(
                            left: 17,
                            top: -6,
                            child: _Lencana(lencana),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                          color: warna,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Lencana extends StatelessWidget {
  const _Lencana(this.jumlah);

  final int jumlah;

  @override
  Widget build(BuildContext context) {
    final w = context.warna;
    return Container(
      constraints: const BoxConstraints(minWidth: 16),
      height: 16,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: w.aksen,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        jumlah > 99 ? '99+' : '$jumlah',
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          height: 1,
          color: w.diAksen,
        ),
      ),
    );
  }
}

/// Tombol tambah klaim: lingkaran penuh berwarna dengan satu tanda "+",
/// warnanya sama dengan tombol melayang yang digantikannya.
///
/// Mengecil sedikit selama ditekan, supaya ketukannya terasa masuk.
class _Tambah extends StatefulWidget {
  const _Tambah({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_Tambah> createState() => _TambahState();
}

class _TambahState extends State<_Tambah> {
  bool _ditekan = false;

  @override
  Widget build(BuildContext context) {
    final w = context.warna;

    return Center(
      child: Tooltip(
        message: 'Klaim Baru',
        // Semantiknya sudah dipegang Semantics di bawah; tanpa ini pembaca
        // layar mengucapkannya dua kali.
        excludeFromSemantics: true,
        child: Semantics(
          button: true,
          label: 'Klaim Baru',
          excludeSemantics: true,
          child: AnimatedScale(
            scale: _ditekan ? 0.9 : 1,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: Material(
              color: w.bahaya,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  widget.onTap();
                },
                onHighlightChanged: (v) => setState(() => _ditekan = v),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: Icon(Icons.add, size: 28, color: w.diAksen),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
