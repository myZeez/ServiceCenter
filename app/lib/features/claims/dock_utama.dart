import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/widgets/kapsul_kaca.dart';

/// Dua isi halaman utama di layar sempit.
enum TabUtama { klaim, servisku }

/// Dock kapsul di dasar halaman utama: Klaim Garansi di kiri, tombol
/// tambah di tengah, Servisku di kanan.
///
/// Tombol tengah hanya ikon "+", tanpa tulisan -- ia membuka formulir klaim
/// baru, bukan berpindah isi, jadi ia tidak pernah "terpilih". Justru karena
/// tengahnya ramping, kedua sisinya bisa lega dan labelnya terbaca utuh.
///
/// Berpindah menu digerakkan, bukan dipotong: penanda kapsul meluncur ke
/// menu yang diketuk, ikonnya membesar dan berwarna penuh, dan isi halaman
/// (lihat ClaimsPage) bergeser ke arah yang sama dengan penandanya. Ketiganya
/// searah supaya mata mengikuti satu gerakan, bukan tiga.
class DockUtama extends StatelessWidget {
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

  /// Penanda tab aktif. Bisa dicari dari luar -- tes membacanya untuk
  /// memastikan ia benar-benar meluncur, bukan melompat.
  static const kunciPenanda = ValueKey<String>('penanda-dock');

  /// Lama gerakan perpindahan. Nol bila pengguna mematikan animasi di
  /// pengaturan sistemnya.
  static Duration lamaGerak(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 300);

  /// Ruang yang harus disisakan di dasar daftar supaya baris terakhirnya
  /// tidak tertutup dock.
  static double ruangBawah(BuildContext context) =>
      tinggi + jarak * 2 + MediaQuery.paddingOf(context).bottom;

  @override
  Widget build(BuildContext context) {
    final w = context.warna;
    final gerak = lamaGerak(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: lebarMaks),
      child: KapsulKaca(
        child: SizedBox(
          height: tinggi,
          child: Padding(
            padding: const EdgeInsets.all(_isiPadding),
            child: LayoutBuilder(
              builder: (context, box) {
                final sisi = (box.maxWidth - _lebarTengah) / 2;

                return Stack(
                  children: [
                    AnimatedPositioned(
                      duration: gerak,
                      curve: Curves.easeOutCubic,
                      left: tab == TabUtama.klaim ? 0 : sisi + _lebarTengah,
                      top: 0,
                      bottom: 0,
                      width: sisi,
                      child: DecoratedBox(
                        key: kunciPenanda,
                        decoration: ShapeDecoration(
                          shape: const StadiumBorder(),
                          color: w.teks.withValues(alpha: 0.09),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        SizedBox(
                          width: sisi,
                          child: _ItemDock(
                            label: 'Klaim Garansi',
                            ikon: Icons.verified_user_outlined,
                            ikonAktif: Icons.verified_user,
                            aktif: tab == TabUtama.klaim,
                            onTap: () => onTab(TabUtama.klaim),
                          ),
                        ),
                        SizedBox(
                          width: _lebarTengah,
                          child: _Tambah(onTap: onKlaimBaru),
                        ),
                        SizedBox(
                          width: sisi,
                          child: _ItemDock(
                            label: 'Servisku',
                            ikon: Icons.build_outlined,
                            ikonAktif: Icons.build,
                            aktif: tab == TabUtama.servisku,
                            lencana: jumlahServisku,
                            onTap: () => onTab(TabUtama.servisku),
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
}

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
              curve: Curves.easeOutCubic,
              builder: (context, t, _) {
                // Yang tidak aktif memakai teks utama yang dipudarkan,
                // bukan teksLembut: di siang hari teksLembut terlalu pucat
                // untuk label sekecil ini di atas kaca.
                final warna = Color.lerp(
                  w.teks.withValues(alpha: 0.62),
                  w.teks,
                  t,
                )!;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Sedikit membesar saat aktif, dan bergantian
                        // antara bentuk garis dan bentuk penuh.
                        Transform.scale(
                          scale: 1 + 0.1 * t,
                          child: AnimatedSwitcher(
                            duration: gerak * 0.7,
                            child: Icon(
                              aktif ? ikonAktif : ikon,
                              key: ValueKey<bool>(aktif),
                              size: 24,
                              color: warna,
                            ),
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
                onTap: widget.onTap,
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
