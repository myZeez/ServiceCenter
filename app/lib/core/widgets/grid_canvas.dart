import 'package:flutter/material.dart';

/// Satu kotak di atas kanvas grid.
class GridArea {
  const GridArea({
    required this.child,
    this.colSpan = 1,
    this.rowSpan = 1,
  });

  final Widget child;

  /// Lebar dalam satuan kolom grid.
  final int colSpan;

  /// Tinggi dalam satuan baris grid.
  final int rowSpan;
}

/// Kanvas grid berkolom tetap, tempat tiap kotak menentukan sendiri berapa
/// kolom dan baris yang ditempatinya.
///
/// Dipakai menggantikan susunan Row/Expanded bertingkat. Perbedaan
/// pentingnya: tinggi kotak ditentukan oleh isinya lewat [rowSpan], bukan
/// dipaksa muat di tinggi layar. Halaman boleh lebih panjang dari jendela
/// dan digulir -- itu jauh lebih baik daripada memampatkan semua isi
/// sampai tidak terbaca.
///
/// Penempatannya mengikuti aturan sederhana: tiap kotak menempati posisi
/// kosong pertama dari kiri atas yang cukup menampungnya. Jadi urutan
/// penulisan menentukan susunan, dan lubang yang tersisa akan terisi kotak
/// berikutnya bila muat.
class GridCanvas extends StatelessWidget {
  const GridCanvas({
    super.key,
    required this.areas,
    this.columns = 12,
    this.rowHeight = 56,
    this.gap = 12,
    this.padding = EdgeInsets.zero,
  });

  final List<GridArea> areas;
  final int columns;
  final double rowHeight;
  final double gap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final lebarIsi = constraints.maxWidth - padding.horizontal;
        final lebarSel = (lebarIsi - gap * (columns - 1)) / columns;

        // Peta sel terpakai. Tumbuh sesuai kebutuhan, jadi jumlah barisnya
        // tidak perlu ditentukan di depan.
        final terpakai = <List<bool>>[];
        final ditempatkan = <_Penempatan>[];

        bool muat(int baris, int kolom, int lebar, int tinggi) {
          for (var r = baris; r < baris + tinggi; r++) {
            while (terpakai.length <= r) {
              terpakai.add(List.filled(columns, false));
            }
            for (var c = kolom; c < kolom + lebar; c++) {
              if (terpakai[r][c]) return false;
            }
          }
          return true;
        }

        for (final area in areas) {
          final lebar = area.colSpan.clamp(1, columns);
          final tinggi = area.rowSpan < 1 ? 1 : area.rowSpan;

          var baris = 0;
          var kolom = 0;
          var ketemu = false;

          while (!ketemu) {
            for (kolom = 0; kolom <= columns - lebar; kolom++) {
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

          ditempatkan.add(
            _Penempatan(area: area, baris: baris, kolom: kolom),
          );
        }

        final jumlahBaris = terpakai.length;
        final tinggiTotal =
            jumlahBaris * rowHeight + (jumlahBaris - 1).clamp(0, 9999) * gap;

        return SingleChildScrollView(
          padding: padding,
          child: SizedBox(
            height: tinggiTotal,
            child: Stack(
              children: [
                for (final p in ditempatkan)
                  Positioned(
                    left: p.kolom * (lebarSel + gap),
                    top: p.baris * (rowHeight + gap),
                    width: p.area.colSpan.clamp(1, columns) * lebarSel +
                        (p.area.colSpan.clamp(1, columns) - 1) * gap,
                    height: p.area.rowSpan * rowHeight +
                        (p.area.rowSpan - 1) * gap,
                    child: p.area.child,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Penempatan {
  const _Penempatan({
    required this.area,
    required this.baris,
    required this.kolom,
  });

  final GridArea area;
  final int baris;
  final int kolom;
}
