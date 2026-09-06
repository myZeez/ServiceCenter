import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/data/models.dart';
import '../../../core/status.dart';
import '../../../core/theme.dart';

final _dateFmt = DateFormat('dd/MM/yyyy');
final _dateShortFmt = DateFormat('dd/MM/yy');

enum _ColId {
  tanggal,
  brand,
  pelanggan,
  telp,
  sn,
  teknisi,
  keluhan,
  rma,
  status,
}

/// Satu kolom beserta ambang lebar tempat ia mulai ditampilkan.
///
/// Tabel tidak pernah digeser mendatar. Ketika jendela menyempit, kolom
/// yang paling sedikit dipakai menghilang lebih dulu -- lebih baik
/// kehilangan satu kolom daripada seluruh baris terpotong di tepi.
class _Col {
  const _Col(this.id, this.label, {this.width, this.flex, this.showAt = 0});

  final _ColId id;
  final String label;
  final double? width;
  final int? flex;
  final double showAt;
}

const _allColumns = [
  _Col(_ColId.tanggal, 'Tanggal', width: 86),
  _Col(_ColId.brand, 'Brand', width: 74),
  _Col(_ColId.pelanggan, 'Pelanggan', flex: 3),
  _Col(_ColId.telp, 'Telp', width: 108, showAt: 1180),
  _Col(_ColId.sn, 'SN', width: 150, showAt: 620),
  _Col(_ColId.teknisi, 'Teknisi', width: 92, showAt: 880),
  _Col(_ColId.keluhan, 'Keluhan', flex: 3, showAt: 1000),
  _Col(_ColId.rma, 'No Perbaikan', width: 112, showAt: 1320),
  _Col(_ColId.status, 'Status', width: 104),
];

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
        final w = constraints.maxWidth;
        final columns = [
          for (final c in _allColumns)
            if (w >= c.showAt) c,
        ];
        // Di bawah 620px tanggal dipersingkat agar kolom nama tetap lega.
        final compact = w < 760;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeaderRow(columns: columns, compact: compact),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: AppSpacing.s),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final c = items[i];
                  return _DataRow(
                    claim: c,
                    columns: columns,
                    compact: compact,
                    brand: brands[c.brandId] ?? '—',
                    technician: technicians[c.teknisiId],
                    onTap: () => onOpen(c),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

double _sidePad(bool compact) => compact ? AppSpacing.s : AppSpacing.sm;

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.columns, required this.compact});

  final List<_Col> columns;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final pad = _sidePad(compact);

    return Container(
      // Garis tebal di bawah kepala tabel: pembatas paling kuat di halaman,
      // menandai awal data.
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.black, width: 1.5)),
      ),
      padding: EdgeInsets.fromLTRB(pad, AppSpacing.s, pad, AppSpacing.xs),
      child: Row(
        children: [
          for (final col in columns)
            _Cell(
              col: col,
              child: Text(
                col.label.toUpperCase(),
                overflow: TextOverflow.clip,
                softWrap: false,
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
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
    required this.columns,
    required this.compact,
    required this.brand,
    required this.technician,
    required this.onTap,
  });

  final Claim claim;
  final List<_Col> columns;
  final bool compact;
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
    final pad = _sidePad(widget.compact);

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
          padding: EdgeInsets.fromLTRB(pad - 3, 13, pad, 13),
          child: Row(
            children: [
              for (final col in widget.columns)
                _Cell(col: col, child: _cellFor(col.id)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cellFor(_ColId id) {
    final c = widget.claim;

    return switch (id) {
      _ColId.tanggal => Row(
        children: [
          Flexible(
            child: Text(
              widget.compact
                  ? _dateShortFmt.format(c.tanggal)
                  : _dateFmt.format(c.tanggal),
              style: _cell,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      _ColId.brand => Text(
        widget.brand.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      _ColId.pelanggan => Text(
        c.namaPelanggan,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        overflow: TextOverflow.ellipsis,
      ),
      _ColId.telp => Text(
        c.telp ?? '—',
        style: _cell,
        overflow: TextOverflow.ellipsis,
      ),
      _ColId.sn => Text(
        c.sn,
        style: _cell.copyWith(letterSpacing: 0.2),
        overflow: TextOverflow.ellipsis,
      ),
      _ColId.teknisi => Text(
        widget.technician ?? '—',
        style: widget.technician == null
            ? _cell.copyWith(color: AppColors.grey)
            : _cell,
        overflow: TextOverflow.ellipsis,
      ),
      _ColId.keluhan => Text(
        c.keluhan ?? '—',
        style: _cell,
        overflow: TextOverflow.ellipsis,
      ),
      _ColId.rma => Text(
        c.noPerbaikan ?? '—',
        style: _cell.copyWith(color: AppColors.grey),
        overflow: TextOverflow.ellipsis,
      ),
      _ColId.status => Align(
        alignment: Alignment.centerLeft,
        child: StatusChip(c.status, compact: true),
      ),
    };
  }
}

const _cell = TextStyle(fontSize: 13, color: AppColors.black);

class _Cell extends StatelessWidget {
  const _Cell({required this.col, required this.child});

  final _Col col;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Kolom terakhir tidak diberi jarak kanan agar isinya tidak terdorong
    // keluar bidang.
    final content = col.id == _ColId.status
        ? child
        : Padding(
            padding: const EdgeInsets.only(right: AppSpacing.s),
            child: child,
          );

    if (col.width != null) return SizedBox(width: col.width, child: content);
    return Expanded(flex: col.flex ?? 1, child: content);
  }
}
