import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

/// Ukuran satu kotak dalam satuan sel grid.
class GridSpan {
  const GridSpan(this.colSpan, this.rowSpan);

  final int colSpan;
  final int rowSpan;

  List<int> toJson() => [colSpan, rowSpan];

  static GridSpan fromJson(List<dynamic> v) =>
      GridSpan((v[0] as num).toInt(), (v[1] as num).toInt());
}

/// Susunan yang dipilih pengguna: ukuran tiap kotak, dan urutannya.
///
/// Urutan menentukan posisi karena penempatannya mengalir. Memindahkan
/// kotak berarti mengubah urutannya, bukan menaruhnya di koordinat bebas --
/// dengan begitu susunannya selalu rapat tanpa lubang yang harus
/// dibereskan sendiri.
class GridLayout {
  const GridLayout({this.spans = const {}, this.order = const []});

  final Map<String, GridSpan> spans;
  final List<String> order;

  bool get isEmpty => spans.isEmpty && order.isEmpty;

  GridLayout copyWith({Map<String, GridSpan>? spans, List<String>? order}) =>
      GridLayout(spans: spans ?? this.spans, order: order ?? this.order);
}

String encodeLayout(GridLayout layout) => jsonEncode({
  'spans': {for (final e in layout.spans.entries) e.key: e.value.toJson()},
  'order': layout.order,
});

GridLayout decodeLayout(String? raw) {
  if (raw == null || raw.isEmpty) return const GridLayout();
  try {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final spans = (map['spans'] as Map<String, dynamic>? ?? {}).map(
      (k, v) => MapEntry(k, GridSpan.fromJson(v as List<dynamic>)),
    );
    final order = (map['order'] as List<dynamic>? ?? []).cast<String>();
    return GridLayout(spans: spans, order: order);
  } catch (_) {
    // Susunan yang rusak tidak boleh membuat halaman gagal terbuka;
    // cukup kembali ke bawaan.
    return const GridLayout();
  }
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

  /// Penanda tetap untuk menyimpan ukuran dan urutan pilihan pengguna.
  final String id;

  final Widget child;

  /// Ukuran bawaan, dipakai sampai pengguna mengubahnya sendiri.
  final int colSpan;
  final int rowSpan;

  final int minColSpan;
  final int minRowSpan;
}

const _durasiTata = Duration(milliseconds: 220);

/// Kanvas grid berkolom tetap. Kotaknya bisa diubah ukurannya dari sisi
/// kanan, sisi bawah, atau sudut kanan bawah, dan dipindah urutannya dengan
/// menyeret pegangan di tepi kiri.
class GridCanvas extends StatefulWidget {
  const GridCanvas({
    super.key,
    required this.areas,
    this.columns = 12,
    this.rowHeight = 52,
    this.gap = 12,
    this.padding = EdgeInsets.zero,
    this.layout = const GridLayout(),
    this.editable = false,
    required this.onLayoutChanged,
  });

  /// Pegangan hanya muncul saat menata. Di luar itu kartunya diam: tanpa
  /// mode tersendiri, satu seretan yang tidak disengaja saat menggulir
  /// halaman sudah cukup untuk mengacak susunan.
  final bool editable;

  final List<GridArea> areas;
  final int columns;
  final double rowHeight;
  final double gap;
  final EdgeInsets padding;
  final GridLayout layout;
  final void Function(GridLayout) onLayoutChanged;

  @override
  State<GridCanvas> createState() => _GridCanvasState();
}

class _GridCanvasState extends State<GridCanvas> {
  final _kanvasKey = GlobalKey();

  // Perubahan sementara selama interaksi, supaya hasilnya terlihat langsung
  // tanpa menunggu tersimpan.
  String? _sedangUbahUkuran;
  GridSpan? _bayanganUkuran;

  String? _sedangDipindah;
  Offset _geser = Offset.zero;
  List<String>? _urutanSementara;

  List<String> get _urutan {
    if (_urutanSementara != null) return _urutanSementara!;

    final ada = {for (final a in widget.areas) a.id};
    // Id yang tersimpan tapi kartunya sudah tidak ada diabaikan, dan kartu
    // baru yang belum pernah tersimpan ditaruh di belakang.
    final hasil = [
      for (final id in widget.layout.order)
        if (ada.contains(id)) id,
    ];
    for (final a in widget.areas) {
      if (!hasil.contains(a.id)) hasil.add(a.id);
    }
    return hasil;
  }

  GridArea _area(String id) => widget.areas.firstWhere((a) => a.id == id);

  GridSpan _span(GridArea a) {
    if (_sedangUbahUkuran == a.id && _bayanganUkuran != null) {
      return _bayanganUkuran!;
    }
    return widget.layout.spans[a.id] ?? GridSpan(a.colSpan, a.rowSpan);
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

        final tata = _hitungTata();
        final baris = tata.jumlahBaris;
        final tinggi =
            baris * widget.rowHeight + (baris - 1).clamp(0, 9999) * widget.gap;

        double lebarDari(int span) => span * lebarSel + (span - 1) * widget.gap;
        double tinggiDari(int span) =>
            span * widget.rowHeight + (span - 1) * widget.gap;

        return SingleChildScrollView(
          padding: widget.padding,
          child: SizedBox(
            key: _kanvasKey,
            height: tinggi,
            child: Stack(
              children: [
                if (_sedangUbahUkuran != null || _sedangDipindah != null)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _PelukisGrid(
                        columns: widget.columns,
                        rows: baris,
                        cellWidth: lebarSel,
                        rowHeight: widget.rowHeight,
                        gap: widget.gap,
                      ),
                    ),
                  ),
                for (final p in tata.daftar)
                  _kotak(p, lebarDari, tinggiDari, langkahX, langkahY),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _kotak(
    _Tata p,
    double Function(int) lebarDari,
    double Function(int) tinggiDari,
    double langkahX,
    double langkahY,
  ) {
    final dipindah = _sedangDipindah == p.area.id;
    final diubah = _sedangUbahUkuran == p.area.id;

    // Kotak yang sedang disentuh mengikuti kursor tanpa jeda; sisanya
    // beranimasi menuju tempat barunya.
    final aktif = dipindah || diubah;
    final kiri = p.kolom * langkahX + (dipindah ? _geser.dx : 0);
    final atas = p.baris * langkahY + (dipindah ? _geser.dy : 0);

    final isi = _IsiKotak(
      area: p.area,
      span: p.span,
      editable: widget.editable,
      sedangDipindah: dipindah,
      sedangDiubah: diubah,
      onMulaiUbah: (arah) => setState(() {
        _sedangUbahUkuran = p.area.id;
        _bayanganUkuran = p.span;
      }),
      onGeserUbah: (arah, dx, dy) {
        final awal =
            widget.layout.spans[p.area.id] ??
            GridSpan(p.area.colSpan, p.area.rowSpan);
        setState(() {
          _bayanganUkuran = GridSpan(
            arah == _Arah.bawah
                ? awal.colSpan
                : (awal.colSpan + (dx / langkahX).round()).clamp(
                    p.area.minColSpan,
                    widget.columns,
                  ),
            arah == _Arah.kanan
                ? awal.rowSpan
                : (awal.rowSpan + (dy / langkahY).round()).clamp(
                    p.area.minRowSpan,
                    40,
                  ),
          );
        });
      },
      onSelesaiUbah: () {
        final akhir = _bayanganUkuran;
        setState(() {
          _sedangUbahUkuran = null;
          _bayanganUkuran = null;
        });
        if (akhir == null) return;
        widget.onLayoutChanged(
          widget.layout.copyWith(
            spans: {...widget.layout.spans, p.area.id: akhir},
            order: _urutan,
          ),
        );
      },
      onMulaiPindah: () => setState(() {
        _sedangDipindah = p.area.id;
        _geser = Offset.zero;
        _urutanSementara = List.of(_urutan);
      }),
      onGeserPindah: (delta, posisiGlobal) {
        setState(() => _geser = delta);
        _perbaruiTujuan(posisiGlobal, langkahX, langkahY);
      },
      onSelesaiPindah: () {
        final urutan = _urutanSementara;
        setState(() {
          _sedangDipindah = null;
          _geser = Offset.zero;
          _urutanSementara = null;
        });
        if (urutan == null) return;
        widget.onLayoutChanged(widget.layout.copyWith(order: urutan));
      },
    );

    return AnimatedPositioned(
      key: ValueKey(p.area.id),
      duration: aktif ? Duration.zero : _durasiTata,
      curve: Curves.easeOutCubic,
      left: kiri,
      top: atas,
      width: lebarDari(p.span.colSpan),
      height: tinggiDari(p.span.rowSpan),
      child: AnimatedScale(
        duration: _durasiTata,
        curve: Curves.easeOutCubic,
        scale: dipindah ? 1.02 : 1,
        child: isi,
      ),
    );
  }

  /// Menentukan kotak mana yang sedang dilewati kursor, lalu menyisipkan
  /// kotak yang diseret ke posisi itu.
  void _perbaruiTujuan(Offset global, double langkahX, double langkahY) {
    final box = _kanvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || _sedangDipindah == null) return;

    final lokal = box.globalToLocal(global);
    final kolom = (lokal.dx / langkahX).floor();
    final baris = (lokal.dy / langkahY).floor();
    if (kolom < 0 || baris < 0) return;

    final tata = _hitungTata();
    for (final p in tata.daftar) {
      final di =
          kolom >= p.kolom &&
          kolom < p.kolom + p.span.colSpan &&
          baris >= p.baris &&
          baris < p.baris + p.span.rowSpan;
      if (!di || p.area.id == _sedangDipindah) continue;

      final urutan = List.of(_urutanSementara ?? _urutan);
      final dari = urutan.indexOf(_sedangDipindah!);
      final ke = urutan.indexOf(p.area.id);
      if (dari < 0 || ke < 0 || dari == ke) return;

      urutan.removeAt(dari);
      urutan.insert(ke, _sedangDipindah!);
      setState(() => _urutanSementara = urutan);
      return;
    }
  }

  _HasilTata _hitungTata() {
    final terpakai = <List<bool>>[];
    final daftar = <_Tata>[];

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

    for (final id in _urutan) {
      final area = _area(id);
      final span = _span(area);
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
        _Tata(
          area: area,
          span: GridSpan(lebar, tinggi),
          baris: baris,
          kolom: kolom,
        ),
      );
    }

    return _HasilTata(daftar, terpakai.length);
  }
}

enum _Arah { kanan, bawah, sudut }

class _HasilTata {
  const _HasilTata(this.daftar, this.jumlahBaris);
  final List<_Tata> daftar;
  final int jumlahBaris;
}

class _Tata {
  const _Tata({
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

/// Isi kotak beserta pegangan-pegangannya.
class _IsiKotak extends StatefulWidget {
  const _IsiKotak({
    required this.area,
    required this.span,
    required this.editable,
    required this.sedangDipindah,
    required this.sedangDiubah,
    required this.onMulaiUbah,
    required this.onGeserUbah,
    required this.onSelesaiUbah,
    required this.onMulaiPindah,
    required this.onGeserPindah,
    required this.onSelesaiPindah,
  });

  final GridArea area;
  final GridSpan span;
  final bool editable;
  final bool sedangDipindah;
  final bool sedangDiubah;

  final void Function(_Arah) onMulaiUbah;
  final void Function(_Arah, double dx, double dy) onGeserUbah;
  final VoidCallback onSelesaiUbah;

  final VoidCallback onMulaiPindah;
  final void Function(Offset delta, Offset global) onGeserPindah;
  final VoidCallback onSelesaiPindah;

  @override
  State<_IsiKotak> createState() => _IsiKotakState();
}

class _IsiKotakState extends State<_IsiKotak> {
  bool _hover = false;
  Offset _akumulasi = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final tampil = _hover || widget.sedangDiubah || widget.sedangDipindah;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: _durasiTata,
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.base),
          boxShadow: widget.sedangDipindah
              ? const [
                  BoxShadow(
                    color: Color(0x1F000000),
                    blurRadius: 20,
                    offset: Offset(0, 6),
                  ),
                ]
              : const [],
        ),
        child: Stack(
          children: [
            Positioned.fill(child: widget.area.child),

            // Di luar mode menata, kartunya hanya isi -- tidak ada pegangan
            // yang bisa tersenggol.
            if (!widget.editable)
              const SizedBox.shrink()
            else ...[
              if (widget.sedangDiubah || widget.sedangDipindah)
                Positioned(
                  right: 8,
                  top: 8,
                  child: _Label(
                    '${widget.span.colSpan} × ${widget.span.rowSpan}',
                  ),
                ),

              // Pegangan pindah di tepi kiri: jauh dari isi kartu, jadi tidak
              // pernah bersaing dengan tombol atau kolom isian di dalamnya.
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 10,
                child: _Pegangan(
                  cursor: SystemMouseCursors.move,
                  tampil: tampil,
                  bentuk: _Bentuk.pindah,
                  onMulai: () {
                    _akumulasi = Offset.zero;
                    widget.onMulaiPindah();
                  },
                  onGeser: (d, global) {
                    _akumulasi += d;
                    widget.onGeserPindah(_akumulasi, global);
                  },
                  onSelesai: widget.onSelesaiPindah,
                ),
              ),

              Positioned(
                right: 0,
                top: 10,
                bottom: 26,
                width: 10,
                child: _Pegangan(
                  cursor: SystemMouseCursors.resizeLeftRight,
                  tampil: tampil,
                  bentuk: _Bentuk.tepi,
                  onMulai: () {
                    _akumulasi = Offset.zero;
                    widget.onMulaiUbah(_Arah.kanan);
                  },
                  onGeser: (d, _) {
                    _akumulasi += d;
                    widget.onGeserUbah(_Arah.kanan, _akumulasi.dx, 0);
                  },
                  onSelesai: widget.onSelesaiUbah,
                ),
              ),

              Positioned(
                left: 10,
                right: 26,
                bottom: 0,
                height: 10,
                child: _Pegangan(
                  cursor: SystemMouseCursors.resizeUpDown,
                  tampil: tampil,
                  bentuk: _Bentuk.tepi,
                  onMulai: () {
                    _akumulasi = Offset.zero;
                    widget.onMulaiUbah(_Arah.bawah);
                  },
                  onGeser: (d, _) {
                    _akumulasi += d;
                    widget.onGeserUbah(_Arah.bawah, 0, _akumulasi.dy);
                  },
                  onSelesai: widget.onSelesaiUbah,
                ),
              ),

              Positioned(
                right: 0,
                bottom: 0,
                width: 26,
                height: 26,
                child: _Pegangan(
                  cursor: SystemMouseCursors.resizeDownRight,
                  tampil: tampil,
                  bentuk: _Bentuk.sudut,
                  onMulai: () {
                    _akumulasi = Offset.zero;
                    widget.onMulaiUbah(_Arah.sudut);
                  },
                  onGeser: (d, _) {
                    _akumulasi += d;
                    widget.onGeserUbah(
                      _Arah.sudut,
                      _akumulasi.dx,
                      _akumulasi.dy,
                    );
                  },
                  onSelesai: widget.onSelesaiUbah,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _Bentuk { pindah, tepi, sudut }

/// Pengenal tarik yang langsung mengklaim sentuhan.
///
/// Tanpa ini, pengenal gulir milik halaman menang lebih dulu: ambangnya 18
/// piksel sementara tarik-bebas baru aktif di 36. Akibatnya menarik
/// pegangan justru menggulir halaman.
class _PenarikLangsung extends PanGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

class _Pegangan extends StatelessWidget {
  const _Pegangan({
    required this.cursor,
    required this.tampil,
    required this.bentuk,
    required this.onMulai,
    required this.onGeser,
    required this.onSelesai,
  });

  final MouseCursor cursor;
  final bool tampil;
  final _Bentuk bentuk;
  final VoidCallback onMulai;
  final void Function(Offset delta, Offset global) onGeser;
  final VoidCallback onSelesai;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: cursor,
      child: RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: {
          _PenarikLangsung:
              GestureRecognizerFactoryWithHandlers<_PenarikLangsung>(
                _PenarikLangsung.new,
                (r) {
                  r
                    ..onStart = ((_) => onMulai())
                    ..onUpdate = ((d) => onGeser(d.delta, d.globalPosition))
                    ..onEnd = ((_) => onSelesai())
                    ..onCancel = (() => onSelesai());
                },
              ),
        },
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: tampil ? 1 : 0,
          child: CustomPaint(painter: _PelukisPegangan(bentuk, context.warna.bahaya)),
        ),
      ),
    );
  }
}

class _PelukisPegangan extends CustomPainter {
  _PelukisPegangan(this.bentuk, this.warna);

  final _Bentuk bentuk;

  /// Pelukis tidak punya BuildContext, jadi warnanya dititipkan dari widget
  /// yang membuatnya -- dan ikut dibandingkan di shouldRepaint, supaya
  /// pegangannya benar-benar dilukis ulang saat temanya berganti.
  final Color warna;

  @override
  void paint(Canvas canvas, Size size) {
    final cat = Paint()
      ..color = warna
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    switch (bentuk) {
      case _Bentuk.pindah:
        // Titik-titik bertumpuk, lambang umum untuk "seret aku".
        final titik = Paint()..color = warna;
        final tengah = size.height / 2;
        for (var i = -2; i <= 2; i++) {
          canvas.drawCircle(Offset(size.width / 2, tengah + i * 6), 1.6, titik);
        }

      case _Bentuk.tepi:
        // Garis tipis sepanjang tepi.
        final horizontal = size.width > size.height;
        canvas.drawLine(
          horizontal
              ? Offset(size.width / 2 - 12, size.height / 2)
              : Offset(size.width / 2, size.height / 2 - 12),
          horizontal
              ? Offset(size.width / 2 + 12, size.height / 2)
              : Offset(size.width / 2, size.height / 2 + 12),
          cat,
        );

      case _Bentuk.sudut:
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
  }

  @override
  bool shouldRepaint(covariant _PelukisPegangan old) =>
      old.bentuk != bentuk || old.warna != warna;
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      color: context.warna.teks,
      borderRadius: BorderRadius.circular(3),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: context.warna.permukaan,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    ),
  );
}

class _PelukisGrid extends CustomPainter {
  _PelukisGrid({
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
    final cat = Paint()..color = const Color(0x12D82C2C);

    for (var c = 0; c < columns; c++) {
      for (var r = 0; r < rows; r++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              c * (cellWidth + gap),
              r * (rowHeight + gap),
              cellWidth,
              rowHeight,
            ),
            const Radius.circular(3),
          ),
          cat,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PelukisGrid old) =>
      old.columns != columns || old.rows != rows;
}
