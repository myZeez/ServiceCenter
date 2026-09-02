import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/omset/omset_providers.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/bento.dart';
import '../../core/widgets/swiss_widgets.dart';

final _rp = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp',
  decimalDigits: 0,
);

/// Aturan omset jasa: target produksi teknisi dan imbalan admin per nota.
///
/// Terpisah dari kartu Bagi Hasil yang mengatur fee garansi dari brand.
/// Dua kantong berbeda; menyatukan pengaturannya akan membuat orang mengira
/// keduanya saling memotong.
class OmsetCard extends ConsumerStatefulWidget {
  const OmsetCard({super.key});

  @override
  ConsumerState<OmsetCard> createState() => _OmsetCardState();
}

class _OmsetCardState extends ConsumerState<OmsetCard> {
  final _target = TextEditingController();
  final _feeAdmin = TextEditingController();

  bool _terisi = false;
  bool _busy = false;

  @override
  void dispose() {
    _target.dispose();
    _feeAdmin.dispose();
    super.dispose();
  }

  double _n(TextEditingController c) => double.tryParse(c.text) ?? 0;

  Future<void> _simpan() async {
    setState(() => _busy = true);
    try {
      await ref.read(supabaseProvider).from('service_settings').update({
        'target_omset': _n(_target),
        'fee_admin_per_nota': _n(_feeAdmin),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', 1);

      await ref.read(syncServiceProvider).syncNow();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aturan omset tersimpan')),
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan. Perlu koneksi.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final aturan = ref.watch(omsetSettingsProvider).valueOrNull;

    if (!_terisi && aturan != null) {
      _target.text = aturan.targetOmset.toInt().toString();
      _feeAdmin.text = aturan.feeAdminPerNota.toInt().toString();
      _terisi = true;
    }

    return BentoCard(
      title: 'Omset Jasa Servis',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: const BoxDecoration(
                color: Color(0x0D0033A0),
                border: Border(
                  left: BorderSide(color: AppColors.blue, width: 3),
                ),
              ),
              child: const Text(
                'Ini jasa yang dibayar pelanggan, bukan fee garansi dari '
                'brand. Keduanya dihitung terpisah dan tidak saling memotong.',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.4,
                  color: AppColors.blue,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s),

            LabeledField(
              label: 'Target Omset Teknisi',
              hint: 'Per orang, tiap bulan. Yang diukur jasa kotor yang '
                  'dihasilkan — bukan bayarannya.',
              child: TextField(
                controller: _target,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  prefixText: 'Rp ',
                  helperText: _n(_target) == 0
                      ? null
                      : _rp.format(_n(_target)),
                  helperStyle: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.grey,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: AppSpacing.s),

            LabeledField(
              label: 'Fee Admin per Nota',
              hint: 'Untuk tiap nota yang keluar, berapa pun biaya jasanya. '
                  'Nota kecil sama repotnya dengan nota besar.',
              child: TextField(
                controller: _feeAdmin,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  prefixText: 'Rp ',
                  helperText: _n(_feeAdmin) == 0
                      ? 'Nol berarti admin tidak menerima fee per nota'
                      : '${_rp.format(_n(_feeAdmin))} × 40 nota = '
                            '${_rp.format(_n(_feeAdmin) * 40)}',
                  helperStyle: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.grey,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),

            const SizedBox(height: AppSpacing.sm),
            FilledButton(
              onPressed: _busy ? null : _simpan,
              child: const Text('SIMPAN ATURAN OMSET'),
            ),
          ],
        ),
      ),
    );
  }
}
