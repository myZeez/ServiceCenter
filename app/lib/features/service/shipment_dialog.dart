import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/data/models.dart';
import '../../core/data/galat.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/swiss_widgets.dart';
import '../scan/scan_page.dart';

final _tglFmt = DateFormat('dd MMM yyyy');
final _iso = DateFormat('yyyy-MM-dd');

Future<void> showShipmentDialog(BuildContext context, {ShipmentEntry? kirim}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Tutup',
    barrierColor: const Color(0x33000000),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, _, _) => ShipmentDialog(kirim: kirim),
    transitionBuilder: (context, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 8 * curved.value,
          sigmaY: 8 * curved.value,
        ),
        child: FadeTransition(
          opacity: curved,
          child: Transform.scale(
            scale: 0.985 + (0.015 * curved.value),
            child: child,
          ),
        ),
      );
    },
  );
}

class ShipmentDialog extends ConsumerStatefulWidget {
  const ShipmentDialog({super.key, this.kirim});

  final ShipmentEntry? kirim;

  bool get isNew => kirim == null;

  @override
  ConsumerState<ShipmentDialog> createState() => _ShipmentDialogState();
}

class _ShipmentDialogState extends ConsumerState<ShipmentDialog> {
  final _formKey = GlobalKey<FormState>();

  final _dari = TextEditingController();
  final _ke = TextEditingController();
  final _user = TextEditingController();
  final _barang = TextEditingController();
  final _sn = TextEditingController();
  final _keluhan = TextEditingController();
  final _kelengkapan = TextEditingController();

  DateTime _tanggalKirim = DateTime.now();
  DateTime? _tanggalKembali;
  String _status = 'ship';
  String? _keterangan;

  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final k = widget.kirim;
    if (k == null) return;

    _dari.text = k.dariCabang;
    _ke.text = k.keCabang;
    _user.text = k.userNama ?? '';
    _barang.text = k.barangNama;
    _sn.text = k.serialNumber ?? '';
    _keluhan.text = k.keluhan ?? '';
    _kelengkapan.text = k.kelengkapan ?? '';
    _tanggalKirim = k.tanggalKirim;
    _tanggalKembali = k.tanggalKembali;
    _status = k.status;
    _keterangan = k.keterangan;
  }

  @override
  void dispose() {
    for (final c in [_dari, _ke, _user, _barang, _sn, _keluhan, _kelengkapan]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _kosongNull(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final data = {
        'tanggal_kirim': _iso.format(_tanggalKirim),
        'dari_cabang': _dari.text.trim(),
        'ke_cabang': _ke.text.trim(),
        'user_nama': _kosongNull(_user),
        'barang_nama': _barang.text.trim(),
        'serial_number': _kosongNull(_sn),
        'keluhan': _kosongNull(_keluhan),
        'kelengkapan': _kosongNull(_kelengkapan),
        'status': _status,
        'tanggal_kembali': _tanggalKembali == null
            ? null
            : _iso.format(_tanggalKembali!),
        'keterangan': _keterangan,
      };

      final client = ref.read(supabaseProvider);
      if (widget.isNew) {
        await client.from('shipments').insert(data);
      } else {
        await client.from('shipments').update(data).eq('id', widget.kirim!.id);
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Catatan pengiriman tersimpan')),
      );
    } on PostgrestException catch (e) {
      setState(() => _error = pesanGalat(e));
    } catch (_) {
      setState(() => _error = 'Gagal menyimpan. Perlu koneksi.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Material(
          color: context.warna.permukaan,
          borderRadius: BorderRadius.circular(AppRadius.base),
          clipBehavior: Clip.antiAlias,
          child: Container(
            width: 880,
            constraints: BoxConstraints(maxHeight: size.height - 80),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.base),
              border: Border.all(color: context.warna.garisHalus),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.sm,
                      AppSpacing.s,
                      AppSpacing.s,
                      AppSpacing.s,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: context.warna.teks, width: 1.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.isNew
                                ? 'Catatan Pengiriman Baru'
                                : 'Ubah Catatan Pengiriman',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          iconSize: 18,
                          color: context.warna.teksLembut,
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _kiri()),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(child: _kanan()),
                        ],
                      ),
                    ),
                  ),
                  _footer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _kiri() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Pengiriman'),
        const SizedBox(height: AppSpacing.s),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: LabeledField(
                label: 'Dari Cabang',
                required: true,
                child: TextFormField(
                  controller: _dari,
                  textCapitalization: TextCapitalization.characters,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: LabeledField(
                label: 'Ke Cabang',
                required: true,
                child: TextFormField(
                  controller: _ke,
                  textCapitalization: TextCapitalization.characters,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s),
        LabeledField(
          label: 'Tanggal Kirim',
          child: OutlinedButton(
            onPressed: () async {
              final p = await showDatePicker(
                context: context,
                initialDate: _tanggalKirim,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (p != null) setState(() => _tanggalKirim = p);
            },
            style: _tombolTanggal(context),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _tglFmt.format(_tanggalKirim),
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        LabeledField(
          label: 'Nama User',
          hint: 'Pemilik atau pengguna unitnya.',
          child: TextFormField(
            controller: _user,
            textCapitalization: TextCapitalization.characters,
          ),
        ),
      ],
    );
  }

  Widget _kanan() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Barang'),
        const SizedBox(height: AppSpacing.s),
        LabeledField(
          label: 'Nama Barang',
          required: true,
          child: TextFormField(
            controller: _barang,
            textCapitalization: TextCapitalization.characters,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        LabeledField(
          label: 'Serial Number',
          child: TextFormField(
            controller: _sn,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              suffixIcon: ScanFieldButton(
                onScanned: (v) => setState(() => _sn.text = v),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        LabeledField(
          label: 'Keluhan',
          child: TextFormField(controller: _keluhan, maxLines: 2),
        ),
        const SizedBox(height: AppSpacing.s),
        LabeledField(
          label: 'Kelengkapan',
          child: TextFormField(controller: _kelengkapan, maxLines: 2),
        ),
        const SizedBox(height: AppSpacing.sm),
        const SectionLabel('Status'),
        const SizedBox(height: AppSpacing.s),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: LabeledField(
                label: 'Status',
                child: DropdownButtonFormField<String>(
                  initialValue: _status,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'ship', child: Text('Dikirim')),
                    DropdownMenuItem(
                      value: 'received',
                      child: Text('Diterima'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _status = v!),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: LabeledField(
                label: 'Keterangan',
                child: DropdownButtonFormField<String>(
                  initialValue: _keterangan,
                  isExpanded: true,
                  hint: const Text('—'),
                  items: const [
                    DropdownMenuItem(value: 'garansi', child: Text('Garansi')),
                    DropdownMenuItem(
                      value: 'non_garansi',
                      child: Text('Non Garansi'),
                    ),
                    DropdownMenuItem(value: 'cid', child: Text('CID')),
                  ],
                  onChanged: (v) => setState(() => _keterangan = v),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s),
        LabeledField(
          label: 'Tanggal Kembali',
          child: OutlinedButton(
            onPressed: () async {
              final p = await showDatePicker(
                context: context,
                initialDate: _tanggalKembali ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (p != null) setState(() => _tanggalKembali = p);
            },
            style: _tombolTanggal(context),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _tanggalKembali == null
                    ? 'Belum kembali'
                    : _tglFmt.format(_tanggalKembali!),
                style: TextStyle(
                  fontSize: 14,
                  color: _tanggalKembali == null
                      ? context.warna.bahaya
                      : context.warna.teks,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _footer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.s,
        AppSpacing.sm,
        AppSpacing.s,
      ),
      decoration: BoxDecoration(
        color: context.warna.teredam,
        border: Border(top: BorderSide(color: context.warna.garisHalus)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _error == null
                ? const SizedBox.shrink()
                : Text(
                    _error!,
                    style: TextStyle(
                      color: context.warna.bahaya,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: const Text('BATAL'),
          ),
          const SizedBox(width: AppSpacing.xs),
          FilledButton(
            onPressed: _busy ? null : _simpan,
            child: _busy
                ? SizedBox(
                    height: 14,
                    width: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.warna.permukaan,
                    ),
                  )
                : const Text('SIMPAN'),
          ),
        ],
      ),
    );
  }
}

/// Gaya tombol pemilih tanggal.
///
/// Berupa fungsi, bukan nilai tetap: bingkainya mengikuti tema yang
/// sedang berlaku, dan tema baru bisa dibaca setelah ada BuildContext.
ButtonStyle _tombolTanggal(BuildContext context) => OutlinedButton.styleFrom(
  alignment: Alignment.centerLeft,
  side: BorderSide(color: context.warna.garisIsian, width: 1),
  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s, vertical: 13),
);
