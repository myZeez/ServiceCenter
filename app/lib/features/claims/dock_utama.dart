import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/widgets/kapsul_kaca.dart';

/// Dua isi halaman utama di layar sempit.
enum TabUtama { klaim, servisku }

/// Dock kapsul di dasar halaman utama: Klaim Garansi di kiri, Klaim Baru
/// menyala di tengah, Servisku di kanan.
///
/// Klaim Baru bukan tab -- ia membuka formulir -- jadi ia tidak pernah
/// "terpilih"; ia disorot karena itulah yang paling sering dituju dan
/// paling sering ditekan dengan satu tangan. Yang menandai tab aktif hanya
/// dua sisinya.
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

  static const tinggi = 64.0;
  static const jarak = 12.0;
  static const lebarMaks = 380.0;

  /// Ruang yang harus disisakan di dasar daftar supaya baris terakhirnya
  /// tidak tertutup dock.
  static double ruangBawah(BuildContext context) =>
      tinggi + jarak * 2 + MediaQuery.paddingOf(context).bottom;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: lebarMaks),
      child: KapsulKaca(
        child: SizedBox(
          height: tinggi,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _ItemDock(
                    label: 'Klaim Garansi',
                    ikon: Icons.verified_user_outlined,
                    ikonAktif: Icons.verified_user,
                    aktif: tab == TabUtama.klaim,
                    onTap: () => onTab(TabUtama.klaim),
                  ),
                ),
                Expanded(flex: 4, child: _Sorot(onTap: onKlaimBaru)),
                Expanded(
                  flex: 3,
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
    // Yang tidak aktif memakai teks utama yang dipudarkan, bukan teksLembut:
    // di siang hari teksLembut terlalu pucat untuk label sekecil ini di
    // atas kaca.
    final warna = aktif ? w.teks : w.teks.withValues(alpha: 0.62);

    return Semantics(
      button: true,
      selected: aktif,
      label: label,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: Ink(
          decoration: ShapeDecoration(
            shape: const StadiumBorder(),
            color: aktif ? w.teks.withValues(alpha: 0.08) : Colors.transparent,
          ),
          child: InkWell(
            onTap: onTap,
            customBorder: const StadiumBorder(),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(aktif ? ikonAktif : ikon, size: 22, color: warna),
                      if (lencana > 0)
                        Positioned(left: 14, top: -6, child: _Lencana(lencana)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: aktif ? FontWeight.w700 : FontWeight.w600,
                        letterSpacing: 0.2,
                        color: warna,
                      ),
                    ),
                  ),
                ],
              ),
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

/// Tombol Klaim Baru: kapsul penuh berwarna, seperti tombol melayang yang
/// digantikannya.
class _Sorot extends StatelessWidget {
  const _Sorot({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final w = context.warna;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Semantics(
        button: true,
        label: 'Klaim Baru',
        excludeSemantics: true,
        child: Material(
          color: w.bahaya,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 20, color: w.diAksen),
                      const SizedBox(width: 4),
                      Text(
                        'KLAIM BARU',
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: w.diAksen,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
