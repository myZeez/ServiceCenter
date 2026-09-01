import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/local/database.dart';
import '../../../core/status.dart';
import '../../../core/theme.dart';

final _dateFmt = DateFormat('dd/MM/yyyy');

/// Lebar tiap kolom. Angka tetap dipakai untuk data berformat pasti
/// (tanggal, status), sisanya dibagi proporsional.
class _Col {
  const _Col(this.label, {this.width, this.flex});
  final String label;
  final double? width;
  final int? flex;
}

const _columns = [
  _Col('Tanggal', width: 92),
  _Col('Brand', width: 78),
  _Col('Pelanggan', flex: 3),
  _Col('Telp', width: 112),
  _Col('SN', width: 158),
  _Col('Teknisi', width: 96),
  _Col('Keluhan', flex: 3),
  _Col('No Perbaikan', width: 116),
  _Col('Status', width: 108),
];

const _minTableWidth = 1180.0;

/// Tabel bergaya Swiss: garis 1px sebagai pemisah, tanpa arsiran baris
/// selang-seling. Yang membedakan baris adalah ruang dan garis, bukan
/// blok warna.
class ClaimsTable extends StatelessWidget {
  const ClaimsTable({
    super.key,
    required this.items,
    required this.brands,
    required this.technicians,
    required this.onOpen,
  });

  final List<Claim> items;
  final Map<int, String> brands;
  final Map<String, String> technicians;
  final void Function(Claim) onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            constraints.maxWidth < _minTableWidth ? _minTableWidth : constraints.maxWidth;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _HeaderRow(),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 96),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final c = items[i];
                      return _DataRow(
                        claim: c,
                        brand: brands[c.brandId] ?? '—',
                        technician: technicians[c.teknisiId],
                        onTap: () => onOpen(c),
                      );
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
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      // Garis tebal di bawah kepala tabel: pembatas paling kuat di halaman,
      // menandai awal data.
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.black, width: 1.5)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          for (final col in _columns)
            _Cell(
              col: col,
              child: Text(
                col.label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: AppColors.black,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DataRow extends StatefulWidget {
  const _DataRow({
    required this.claim,
    required this.brand,
    required this.technician,
    required this.onTap,
  });

  final Claim claim;
  final String brand;
  final String? technician;
  final VoidCallback onTap;

  @override
  State<_DataRow> createState() => _DataRowState();
}

class _DataRowState extends State<_DataRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.claim;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: _hover ? AppColors.lightGrey : AppColors.white,
            border: Border(
              bottom: const BorderSide(color: Color(0xFFE4E7E7)),
              // Penanda merah di tepi kiri saat kursor lewat -- menggantikan
              // arsiran baris, dan tetap terbaca di layar apa pun.
              left: BorderSide(
                color: _hover ? AppColors.red : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md - 3,
            14,
            AppSpacing.md,
            14,
          ),
          child: Row(
            children: [
              _Cell(
                col: _columns[0],
                child: Row(
                  children: [
                    if (c.syncPending)
                      const Padding(
                        padding: EdgeInsets.only(right: 5),
                        child: Icon(
                          Icons.schedule,
                          size: 12,
                          color: AppColors.red,
                        ),
                      ),
                    Text(_dateFmt.format(c.tanggal), style: _cellStyle),
                  ],
                ),
              ),
              _Cell(
                col: _columns[1],
                child: Text(
                  widget.brand.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              _Cell(
                col: _columns[2],
                child: Text(
                  c.namaPelanggan,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _Cell(col: _columns[3], child: Text(c.telp ?? '—', style: _cellStyle)),
              _Cell(
                col: _columns[4],
                child: Text(
                  c.sn,
                  style: _cellStyle.copyWith(letterSpacing: 0.3),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _Cell(
                col: _columns[5],
                child: Text(
                  widget.technician ?? '—',
                  style: widget.technician == null
                      ? _cellStyle.copyWith(color: AppColors.grey)
                      : _cellStyle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _Cell(
                col: _columns[6],
                child: Text(
                  c.keluhan ?? '—',
                  style: _cellStyle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _Cell(
                col: _columns[7],
                child: Text(
                  c.noPerbaikan ?? '—',
                  style: _cellStyle.copyWith(color: AppColors.grey),
                ),
              ),
              _Cell(
                col: _columns[8],
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: StatusChip(c.status, compact: true),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _cellStyle = TextStyle(fontSize: 13, color: AppColors.black);

class _Cell extends StatelessWidget {
  const _Cell({required this.col, required this.child});

  final _Col col;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.only(right: AppSpacing.s),
      child: child,
    );

    if (col.width != null) return SizedBox(width: col.width, child: content);
    return Expanded(flex: col.flex ?? 1, child: content);
  }
}
