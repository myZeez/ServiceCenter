import 'dart:convert';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Ukuran satu kotak dalam satuan sel grid.
class GridSpan {
  const GridSpan(this.colSpan, this.rowSpan);

  final int colSpan;
  final int rowSpan;

  GridSpan copyWith({int? colSpan, int? rowSpan}) =>
      GridSpan(colSpan ?? this.colSpan, rowSpan ?? this.rowSpan);

  List<int> toJson() => [colSpan, rowSpan];

  static GridSpan fromJson(List<dynamic> v) =>
      GridSpan((v[0] as num).toInt(), (v[1] as num).toInt());
}

/// Satu kotak di atas kanvas grid.
class GridArea {
  const GridArea({
    required this.id,
    required this.child,
    this.colSpan = 4,
    this.rowSpan = 6,
    this.minColSpan = 3,
    this.minRowSpan = 3,
  });

  /// Penanda tetap untuk menyimpan ukuran yang dipilih pengguna.
  final String id;

  final Widget child;

  /// Ukuran bawaan, dipakai sampai pengguna mengubahnya sendiri.
  final int colSpan;
  final int rowSpan;

  final int minColSpan;
  final int minRowSpan;
}

/// Kanvas grid berkolom tetap yang kotaknya bisa diubah ukurannya dengan
/// menarik sudut kanan bawah.
///
/// Yang diatur pengguna hanya UKURAN; posisinya mengalir sendiri mengisi
/// ruang kosong pertama dari kiri atas. Ini disengaja: memindahkan kotak
/// secara bebas menuntut penyelesaian tabrakan, dan hasilnya justru sering
/// meninggalkan lubang yang harus dirapikan manual. Dengan mengalir, satu
/// kotak yang dilebarkan langsung membuat sisanya menata ulang diri.
class GridCanvas extends StatefulWidget {
  const GridCanvas({
    super.key,
    required this.areas,
    this.columns = 12,
    this.rowHeight = 52,
    this.gap = 12,
    this.padding = EdgeInsets.zero,
    this.spans = const {},
    this.onSpansChanged,
  });

  final List<GridArea> areas;
  final int columns;
  final double rowHeight;
  final double gap;
  final EdgeInsets padding;

  /// Ukuran yang sudah pernah diatur pengguna, per id kotak.
  final Map<String, GridSpan> spans;

  final void Function(Map<String, GridSpan>)? onSpansChanged;

  @override
  State<GridCanvas> createState() => GridCanvasState();
}

class GridCanvasState extends State<GridCanvas> {
  /// Ukuran sementara selama penarikan berlangsung, supaya perubahannya
  /// terlihat langsung tanpa menunggu disimpan.
  String? _sedangDitarik;
  GridSpan? _bayangan;

  GridSpan _spanUntuk(GridArea a) {
    if (_sedangDitarik == a.id && _bayangan != null) return _bayangan!;
    return widget.spans[a.id] ?? GridSpan(a.colSpan, a.rowSpan);
  }

  void _commit(GridArea area, GridSpan span) {
    final map = Map<String, GridSpan>.from(widget.spans)..[area.id] = span;
    widget.onSpansChanged?.call(map);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final lebarIsi = constraints.maxWidth - widget.padding.horizontal;
        final lebarSel =
            (lebarIsi - widget.gap * (widget.columns - 1)) / widget.columns;
        final langkahX = lebarSel + widget.gap;
        final langkahY = widget.rowHeight + widget.gap;

        final penempatan = _hitungPenempatan();
        final jumlahBaris = penempatan.jumlahBaris;
        final tinggiTotal = jumlahBaris * widget.rowHeight +
            (jumlahBaris - 1).clamp(0, 9999) * widget.gap;

        return SingleChildScrollView(
          padding: widget.padding,
          child: SizedBox(
            height: tinggiTotal,
            child: Stack(
              children: [
                // Garis grid hanya muncul saat sedang ditarik: selebihnya
                // hanya menambah kebisingan visual.
                if (_sedangDitarik != null)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _GridPainter(
                        columns: widget.columns,
                        rows: jumlahBaris,
                        cellWidth: lebarSel,
                        rowHeight: widget.rowHeight,
                        gap: widget.gap,
                      ),
                    ),
                  ),
                for (final p in penempatan.daftar)
                  Positioned(
                    left: p.kolom * langkahX,
                    top: p.baris * langkahY,
                    width: p.span.colSpan * lebarSel +
                        (p.span.colSpan - 1) * widget.gap,
                    height: p.span.rowSpan * widget.rowHeight +
                        (p.span.rowSpan - 1) * widget.gap,
                    child: _KotakGrid(
                      area: p.area,
                      span: p.span,
                      sedangDitarik: _sedangDitarik == p.area.id,
                      onMulai: () => setState(() {
                        _sedangDitarik = p.area.id;
                        _bayangan = p.span;
                      }),
                      onGeser: (dx, dy) {
                        final awal = widget.spans[p.area.id] ??
                            GridSpan(p.area.colSpan, p.area.rowSpan);
                        setState(() {
                          _bayangan = GridSpan(
                            (awal.colSpan + (dx / langkahX).round())
                                .clamp(p.area.minColSpan, widget.columns),
                            (awal.rowSpan + (dy / langkahY).round())
                                .clamp(p.area.minRowSpan, 40),
                          );
                        });
                      },
                      onSelesai: () {
                        final akhir = _bayangan;
                        setState(() {
                          _sedangDitarik = null;
                          _bayangan = null;
                        });
                        if (akhir != null) _commit(p.area, akhir);
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  _HasilPenempatan _hitungPenempatan() {
    final terpakai = <List<bool>>[];
    final daftar = <_Penempatan>[];

    bool muat(int baris, int kolom, int lebar, int tinggi) {
      for (var r = baris; r < baris + tinggi; r++) {
        while (terpakai.length <= r) {
          terpakai.add(List.filled(widget.columns, false));
        }
        for (var c = kolom; c < kolom + lebar; c++) {
          if (terpakai[r][c]) return false;
        }
      }
      return true;
    }

    for (final area in widget.areas) {
      final span = _spanUntuk(area);
      final lebar = span.colSpan.clamp(1, widget.columns);
      final tinggi = span.rowSpan < 1 ? 1 : span.rowSpan;

      var baris = 0;
      var kolom = 0;
      var ketemu = false;

      while (!ketemu) {
        for (kolom = 0; kolom <= widget.columns - lebar; kolom++) {
          if (muat(baris, kolom, lebar, tinggi)) {
            ketemu = true;
            break;
          }
        }
        if (!ketemu) baris++;
      }

      for (var r = baris; r < baris + tinggi; r++) {
        for (var c = kolom; c < kolom + lebar; c++) {
          terpakai[r][c] = true;
        }
      }

      daftar.add(
        _Penempatan(
          area: area,
          span: GridSpan(lebar, tinggi),
          baris: baris,
          kolom: kolom,
        ),
      );
    }

    return _HasilPenempatan(daftar, terpakai.length);
  }
}

class _HasilPenempatan {
  const _HasilPenempatan(this.daftar, this.jumlahBaris);
  final List<_Penempatan> daftar;
  final int jumlahBaris;
}

class _Penempatan {
  const _Penempatan({
    required this.area,
    required this.span,
    required this.baris,
    required this.kolom,
  });

  final GridArea area;
  final GridSpan span;
  final int baris;
  final int kolom;
}

/// Pembungkus kotak: isinya, plus pegangan penarik di sudut kanan bawah.
class _KotakGrid extends StatefulWidget {
  const _KotakGrid({
    required this.area,
    required this.span,
    required this.sedangDitarik,
    required this.onMulai,
    required this.onGeser,
    required this.onSelesai,
  });

  final GridArea area;
  final GridSpan span;
  final bool sedangDitarik;
  final VoidCallback onMulai;
  final void Function(double dx, double dy) onGeser;
  final VoidCallback onSelesai;

  @override
  State<_KotakGrid> createState() => _KotakGridState();
}

class _KotakGridState extends State<_KotakGrid> {
  bool _hover = false;
  Offset _akumulasi = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final tampilkanPegangan = _hover || widget.sedangDitarik;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Stack(
        children: [
          Positioned.fill(child: widget.area.child),

          // Ukuran ditampilkan saat menarik supaya pengguna tahu sedang
          // memilih berapa kolom dan baris, bukan sekadar menggeser piksel.
          if (widget.sedangDitarik)
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.black,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  '${widget.span.colSpan} × ${widget.span.rowSpan}',
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

          Positioned(
            right: 0,
            bottom: 0,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeDownRight,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (_) {
                  _akumulasi = Offset.zero;
                  widget.onMulai();
                },
                onPanUpdate: (d) {
                  _akumulasi += d.delta;
                  widget.onGeser(_akumulasi.dx, _akumulasi.dy);
                },
                onPanEnd: (_) => widget.onSelesai(),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: tampilkanPegangan ? 1 : 0,
                  child: const _Pegangan(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pegangan extends StatelessWidget {
  const _Pegangan();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _PegangatPainter()),
    );
  }
}

class _PegangatPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cat = Paint()
      ..color = AppColors.red
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    // Dua garis miring sejajar -- lambang yang sudah umum dipahami sebagai
    // "tarik untuk mengubah ukuran".
    canvas.drawLine(
      Offset(size.width - 3, size.height - 11),
      Offset(size.width - 11, size.height - 3),
      cat,
    );
    canvas.drawLine(
      Offset(size.width - 3, size.height - 6),
      Offset(size.width - 6, size.height - 3),
      cat,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.columns,
    required this.rows,
    required this.cellWidth,
    required this.rowHeight,
    required this.gap,
  });

  final int columns;
  final int rows;
  final double cellWidth;
  final double rowHeight;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final cat = Paint()..color = const Color(0x14D82C2C);

    for (var c = 0; c < columns; c++) {
      for (var r = 0; r < rows; r++) {
        canvas.drawRect(
          Rect.fromLTWH(
            c * (cellWidth + gap),
            r * (rowHeight + gap),
            cellWidth,
            rowHeight,
          ),
          cat,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) =>
      old.columns != columns || old.rows != rows;
}

// =====================================================================
// Penyimpanan susunan
// =====================================================================

String encodeSpans(Map<String, GridSpan> spans) =>
    jsonEncode({for (final e in spans.entries) e.key: e.value.toJson()});

Map<String, GridSpan> decodeSpans(String? raw) {
  if (raw == null || raw.isEmpty) return const {};
  try {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return {
      for (final e in map.entries)
        e.key: GridSpan.fromJson(e.value as List<dynamic>),
    };
  } catch (_) {
    // Susunan yang rusak tidak boleh membuat halaman gagal terbuka;
    // cukup kembali ke ukuran bawaan.
    return const {};
  }
}
