import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/data/galat.dart';
import '../../core/data/models.dart';
import '../../core/kaca/overlay_kaca.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/swiss_widgets.dart';
import 'part_status.dart';

final _rp = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp',
  decimalDigits: 0,
);
final _tgl = DateFormat('dd/MM/yyyy');
final _iso = DateFormat('yyyy-MM-dd');

/// Data pembelian sebuah pesanan part: yang diisi gudang.
///
/// Sengaja bukan formulir tanya harga. Gudang hanya mengisi apa yang terjadi
/// saat part dibeli -- modal, tanggal order, nomor PO, dan dari mana
/// belinya. Harga jual, DP, dan tahap tetap milik admin; server menolak
/// perubahan itu dari akun gudang, jadi layar ini tidak menawarkannya.
Future<void> showGudangPembelian(BuildContext context, PartOrder pesanan) =>
    tampilkanDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => GudangPembelianDialog(pesanan: pesanan),
    );

class GudangPembelianDialog extends ConsumerStatefulWidget {
  const GudangPembelianDialog({super.key, required this.pesanan});

  final PartOrder pesanan;

  @override
  ConsumerState<GudangPembelianDialog> createState() =>
      _GudangPembelianDialogState();
}

class _GudangPembelianDialogState extends ConsumerState<GudangPembelianDialog> {
  final _hpp = TextEditingController();
  final _po = TextEditingController();
  final _asal = TextEditingController();
  final _catatan = TextEditingController();
  DateTime? _tanggalOrder;
  bool _modalTerbaca = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.pesanan;
    _po.text = p.noPo ?? '';
    _asal.text = p.keterangan ?? '';
    _catatan.text = p.catatan ?? '';
    _tanggalOrder = p.tanggalOrder;
  }

  @override
  void dispose() {
    for (final c in [_hpp, _po, _asal, _catatan]) {
      c.dispose();
    }
    super.dispose();
  }

  double? get _hppAngka {
    final d = _hpp.text.replaceAll(RegExp(r'[^0-9]'), '');
    return d.isEmpty ? null : double.parse(d);
  }

  Future<void> _simpan() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(databaseProvider)
          .simpanPembelianPart(
            widget.pesanan.id,
            tanggalOrder: _tanggalOrder == null
                ? null
                : _iso.format(_tanggalOrder!),
            noPo: _po.text.trim().isEmpty ? null : _po.text.trim(),
            asal: _asal.text.trim().isEmpty
                ? null
                : _asal.text.trim().toUpperCase(),
            catatan: _catatan.text.trim().isEmpty ? null : _catatan.text.trim(),
            hpp: _hppAngka,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Data pembelian tersimpan')));
    } catch (e) {
      setState(() => _error = pesanGalat(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pesanan;

    // Modal datang belakangan dari server; dibaca sekali saja supaya yang
    // sedang diketik tidak tertimpa nilai lama.
    if (!_modalTerbaca) {
      final daftar = ref.watch(partCostsProvider);
      if (daftar.hasValue) {
        _modalTerbaca = true;
        final hpp = ref.read(partCostProvider(p.id))?.hpp;
        if (hpp != null) _hpp.text = hpp.toInt().toString();
      }
    }

    final hpp = _hppAngka;
    final untung = (hpp != null && p.harga != null) ? p.harga! - hpp : null;

    return AlertDialog(
      title: const Text('Data pembelian part'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                p.customerNama,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                [
                  p.partReq,
                  if ((p.barangType ?? '').isNotEmpty) p.barangType!,
                ].join('  ·  '),
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  PartTahapChip(p.tahap, compact: true),
                  const SizedBox(width: AppSpacing.s),
                  Text(
                    'Harga jual ${p.harga == null ? '—' : _rp.format(p.harga)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s),
              LabeledField(
                label: 'HPP (Modal)',
                hint: untung == null
                    ? 'Harga beli dari supplier.'
                    : 'Untung ${_rp.format(untung)}',
                child: TextField(
                  controller: _hpp,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(prefixText: 'Rp '),
                ),
              ),
              const SizedBox(height: AppSpacing.s),
              LabeledField(
                label: 'Tanggal Order',
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _tanggalOrder ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 60)),
                    );
                    if (d != null) setState(() => _tanggalOrder = d);
                  },
                  icon: const Icon(Icons.calendar_today, size: 15),
                  label: Text(
                    _tanggalOrder == null
                        ? 'Belum dipesan'
                        : _tgl.format(_tanggalOrder!),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s),
              LabeledField(
                label: 'No PO',
                hint: 'Atau nama tempat membeli.',
                child: TextField(
                  controller: _po,
                  textCapitalization: TextCapitalization.characters,
                ),
              ),
              const SizedBox(height: AppSpacing.s),
              LabeledField(
                label: 'Asal Part',
                hint: 'OEM TOPED, OEM ATCOM, ASUS ID, dan seterusnya.',
                child: TextField(
                  controller: _asal,
                  textCapitalization: TextCapitalization.characters,
                ),
              ),
              const SizedBox(height: AppSpacing.s),
              LabeledField(
                label: 'Catatan',
                child: TextField(controller: _catatan, maxLines: 2),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.s),
                Text(
                  _error!,
                  style: TextStyle(color: context.warna.bahaya, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('BATAL'),
        ),
        FilledButton(
          onPressed: _busy ? null : _simpan,
          child: const Text('SIMPAN'),
        ),
      ],
    );
  }
}
