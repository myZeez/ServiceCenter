import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/data/models.dart';
import '../../core/kaca/overlay_kaca.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/swiss_widgets.dart';

final _rpPartner = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp',
  decimalDigits: 0,
);

Future<void> showPartnerServiceDialog(
  BuildContext context, {
  required ServiceOrderEntry nota,
  PartnerServiceEntry? partner,
}) => tampilkanDialog(
  context: context,
  builder: (_) => PartnerServiceDialog(nota: nota, partner: partner),
);

class PartnerServiceDialog extends ConsumerStatefulWidget {
  const PartnerServiceDialog({super.key, required this.nota, this.partner});

  final ServiceOrderEntry nota;
  final PartnerServiceEntry? partner;

  @override
  ConsumerState<PartnerServiceDialog> createState() =>
      _PartnerServiceDialogState();
}

class _PartnerServiceDialogState extends ConsumerState<PartnerServiceDialog> {
  final _form = GlobalKey<FormState>();
  final _hpp = TextEditingController();
  final _up = TextEditingController();
  final _catatan = TextEditingController();
  late String _status;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.partner;
    _status = p?.status ?? 'dikirim';
    _hpp.text = p?.hpp?.toStringAsFixed(0) ?? '';
    _up.text = p?.upBiaya?.toStringAsFixed(0) ?? '';
    _catatan.text = p?.catatan ?? '';
  }

  @override
  void dispose() {
    _hpp.dispose();
    _up.dispose();
    _catatan.dispose();
    super.dispose();
  }

  double? get _hppNilai => double.tryParse(_hpp.text.replaceAll('.', ''));
  double? get _upNilai => double.tryParse(_up.text.replaceAll('.', ''));

  Future<void> _simpan() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(databaseProvider).simpanPartnerService({
        'service_order_id': widget.nota.id,
        'status': _status,
        'hpp': _status == 'selesai' ? _hppNilai : null,
        'up_biaya': _status == 'selesai' ? _upNilai : null,
        'catatan': _catatan.text.trim().isEmpty ? null : _catatan.text.trim(),
      });
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _status == 'selesai'
                ? 'Biaya partner disimpan'
                : 'Nota dikirim ke partner',
          ),
        ),
      );
    } catch (_) {
      setState(() => _error = 'Gagal menyimpan data partner. Coba lagi.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nota = widget.nota;
    final selesai = _status == 'selesai';
    final selisih = selesai && _hppNilai != null && _upNilai != null
        ? _upNilai! - _hppNilai!
        : null;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.partner == null
                      ? 'KIRIM KE PARTNER'
                      : 'SERVIS PARTNER',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${nota.noNota}  ·  ${nota.customerNama}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: AppSpacing.s),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s),
                  color: context.warna.teredam,
                  child: Text(
                    '${nota.barangNama}${(nota.barangType ?? '').trim().isEmpty ? '' : ' · ${nota.barangType}'}\n'
                    '${nota.perbaikan ?? nota.keluhan ?? '—'}',
                  ),
                ),
                const SizedBox(height: AppSpacing.s),
                LabeledField(
                  label: 'Status Partner',
                  child: DropdownButtonFormField<String>(
                    initialValue: _status,
                    items: const [
                      DropdownMenuItem(
                        value: 'dikirim',
                        child: Text('Dikirim ke Partner'),
                      ),
                      DropdownMenuItem(
                        value: 'selesai',
                        child: Text('Selesai'),
                      ),
                    ],
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _status = v!),
                  ),
                ),
                if (selesai) ...[
                  const SizedBox(height: AppSpacing.s),
                  Row(
                    children: [
                      Expanded(
                        child: LabeledField(
                          label: 'HPP',
                          required: true,
                          child: TextFormField(
                            controller: _hpp,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              prefixText: 'Rp ',
                            ),
                            validator: (v) =>
                                selesai && _hppNilai == null ? 'Isi HPP' : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s),
                      Expanded(
                        child: LabeledField(
                          label: 'Up Biaya Service',
                          required: true,
                          child: TextFormField(
                            controller: _up,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              prefixText: 'Rp ',
                            ),
                            validator: (v) => selesai && _upNilai == null
                                ? 'Isi up biaya'
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s),
                  Text(
                    'INCOME / SELISIH  ${selisih == null ? '—' : _rpPartner.format(selisih)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: selisih != null && selisih < 0
                          ? context.warna.bahaya
                          : context.warna.aksen,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.s),
                LabeledField(
                  label: 'Catatan',
                  child: TextFormField(controller: _catatan, maxLines: 2),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.s),
                  Text(_error!, style: TextStyle(color: context.warna.bahaya)),
                ],
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('BATAL'),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    FilledButton(
                      onPressed: _busy ? null : _simpan,
                      child: Text(_busy ? 'MENYIMPAN…' : 'SIMPAN'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
