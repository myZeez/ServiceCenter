import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/local/database.dart';
import '../../core/providers.dart';
import '../../core/revenue/revenue_providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/bento.dart';
import '../../core/widgets/swiss_widgets.dart';

final _rp = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
final _tgl = DateFormat('d MMM yyyy');
final _iso = DateFormat('yyyy-MM-dd');

// Pembacaan memakai data lokal supaya halaman ini tetap terbaca saat
// offline. Penyimpanan tetap langsung ke server -- aturan bagi hasil
// berlaku untuk semua perangkat, jadi tidak boleh diantrekan dan bentrok.

// =====================================================================
// Fee per brand
// =====================================================================

class BrandFeesCard extends ConsumerWidget {
  const BrandFeesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brands = ref.watch(allBrandsProvider).valueOrNull ?? const <Brand>[];
    final fees = ref.watch(currentFeesProvider);

    return BentoCard(
      title: 'Fee per Brand',
      padding: EdgeInsets.zero,
      child: brands.isEmpty
          ? const _CardMessage('Belum ada brand.')
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              itemCount: brands.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (context, i) {
                final b = brands[i];
                return _FeeRow(
                  brand: b,
                  fee: fees[b.id],
                  onEdit: () => _editFee(context, ref, b, fees[b.id]),
                );
              },
            ),
    );
  }

  Future<void> _editFee(
    BuildContext context,
    WidgetRef ref,
    Brand brand,
    BrandFeeEntry? current,
  ) async {
    final result = await showDialog<({double fee, DateTime dari})>(
      context: context,
      builder: (_) => _FeeDialog(
        brand: brand.nama,
        initialFee: current == null ? '' : '${current.fee.toInt()}',
      ),
    );
    if (result == null || !context.mounted) return;

    try {
      // Baris baru per tanggal berlaku, bukan menimpa yang lama. Rekap
      // periode yang sudah lewat harus tetap memakai fee yang berlaku
      // saat itu.
      await ref.read(supabaseProvider).from('brand_fees').upsert(
        {
          'brand_id': brand.id,
          'fee': result.fee,
          'berlaku_dari': _iso.format(result.dari),
        },
        onConflict: 'brand_id,berlaku_dari',
      );
      await ref.read(syncServiceProvider).syncNow();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan fee. Perlu koneksi. $e')),
      );
    }
  }
}

class _FeeRow extends StatelessWidget {
  const _FeeRow({required this.brand, required this.fee, required this.onEdit});

  final Brand brand;
  final BrandFeeEntry? fee;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final belum = fee == null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  brand.nama,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                if (!belum)
                  Text(
                    'berlaku sejak ${_tgl.format(fee!.berlakuDari)}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
              ],
            ),
          ),
          Text(
            belum ? 'BELUM DIATUR' : _rp.format(fee!.fee),
            style: TextStyle(
              fontSize: belum ? 10 : 14,
              fontWeight: FontWeight.w700,
              letterSpacing: belum ? 0.8 : 0,
              color: belum ? AppColors.red : AppColors.black,
            ),
          ),
          const SizedBox(width: AppSpacing.s),
          InlineAction(label: belum ? 'Atur' : 'Ubah', onTap: onEdit),
        ],
      ),
    );
  }
}

class _FeeDialog extends StatefulWidget {
  const _FeeDialog({required this.brand, required this.initialFee});

  final String brand;
  final String initialFee;

  @override
  State<_FeeDialog> createState() => _FeeDialogState();
}

class _FeeDialogState extends State<_FeeDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _fee = TextEditingController(text: widget.initialFee);

  // Bawaannya awal kuartal berjalan, karena begitulah fee biasanya berubah.
  DateTime _dari = DateTime(
    DateTime.now().year,
    ((DateTime.now().month - 1) ~/ 3) * 3 + 1,
    1,
  );

  @override
  void dispose() {
    _fee.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Fee ${widget.brand}'),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LabeledField(
                label: 'Fee per Unit',
                required: true,
                hint: 'Nilai yang dibayar brand untuk satu unit selesai.',
                child: TextFormField(
                  controller: _fee,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(prefixText: 'Rp '),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    return (n == null || n <= 0)
                        ? 'Isi angka lebih dari 0'
                        : null;
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.s),
              LabeledField(
                label: 'Berlaku Sejak',
                hint: 'Klaim sebelum tanggal ini tetap memakai fee lama.',
                child: OutlinedButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _dari,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
                    );
                    if (picked != null) setState(() => _dari = picked);
                  },
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    side: const BorderSide(color: Color(0xFFCFD5D4), width: 1),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s,
                      vertical: 13,
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _tgl.format(_dari),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('BATAL'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(context, (fee: double.parse(_fee.text), dari: _dari));
          },
          child: const Text('SIMPAN'),
        ),
      ],
    );
  }
}

// =====================================================================
// Aturan bagi hasil
// =====================================================================

class RevenueSplitCard extends ConsumerStatefulWidget {
  const RevenueSplitCard({super.key});

  @override
  ConsumerState<RevenueSplitCard> createState() => _RevenueSplitCardState();
}

class _RevenueSplitCardState extends ConsumerState<RevenueSplitCard> {
  final _toko = TextEditingController();
  final _admin = TextEditingController();
  final _teknisi = TextEditingController();
  final Map<String, TextEditingController> _shares = {};

  String _metode = 'per_unit';
  bool _loaded = false;
  bool _busy = false;

  @override
  void dispose() {
    _toko.dispose();
    _admin.dispose();
    _teknisi.dispose();
    for (final c in _shares.values) {
      c.dispose();
    }
    super.dispose();
  }

  double _num(TextEditingController c) => double.tryParse(c.text) ?? 0;

  double get _sisaPeran =>
      100 - _num(_toko) - _num(_admin) - _num(_teknisi);

  double get _sisaTeknisi =>
      100 - _shares.values.fold<double>(0, (a, c) => a + _num(c));

  Future<void> _save() async {
    if (_sisaPeran != 0) return;
    setState(() => _busy = true);

    try {
      final client = ref.read(supabaseProvider);
      await client.from('revenue_settings').update({
        'persen_toko': _num(_toko),
        'persen_admin': _num(_admin),
        'persen_teknisi': _num(_teknisi),
        'metode_teknisi': _metode,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', 1);

      if (_metode == 'manual') {
        for (final e in _shares.entries) {
          await client.from('technician_shares').upsert({
            'profile_id': e.key,
            'persen': _num(e.value),
          });
        }
      }

      await ref.read(syncServiceProvider).syncNow();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aturan bagi hasil tersimpan')),
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
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
    final config = ref.watch(revenueConfigProvider).valueOrNull;
    final shares = ref.watch(technicianSharesMapProvider);
    final techs = ref.watch(techniciansProvider).valueOrNull ?? const <Profile>[];

    if (!_loaded) {
      _toko.text = '${(config?.persenToko ?? 30).toInt()}';
      _admin.text = '${(config?.persenAdmin ?? 10).toInt()}';
      _teknisi.text = '${(config?.persenTeknisi ?? 60).toInt()}';
      _metode = config?.metodeTeknisi ?? 'per_unit';
      // Menunggu sampai aturan benar-benar tersedia, supaya isian tidak
      // terlanjur terkunci pada nilai bawaan lalu menimpa yang asli.
      if (config != null) _loaded = true;
    }
    for (final t in techs) {
      _shares.putIfAbsent(
        t.id,
        () => TextEditingController(text: '${(shares[t.id] ?? 0).toInt()}'),
      );
    }

    return BentoCard(
      title: 'Bagi Hasil',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _PercentRow(label: 'Toko', controller: _toko, onChanged: _touch),
            _PercentRow(label: 'Admin', controller: _admin, onChanged: _touch),
            _PercentRow(
              label: 'Teknisi',
              controller: _teknisi,
              onChanged: _touch,
            ),
            const Divider(),
            _Remaining(sisa: _sisaPeran),

            const SizedBox(height: AppSpacing.s),
            Text(
              'PEMBAGIAN ANTAR TEKNISI',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 6),
            _MethodOption(
              value: 'per_unit',
              group: _metode,
              title: 'Per unit dikerjakan',
              subtitle: 'Sesuai nilai yang dihasilkan masing-masing. Tidak '
                  'perlu diubah saat jumlah teknisi berubah.',
              recommended: true,
              onTap: (v) => setState(() => _metode = v),
            ),
            _MethodOption(
              value: 'rata',
              group: _metode,
              title: 'Rata',
              subtitle: 'Jatah teknisi dibagi sama besar, berapa pun unit '
                  'yang dikerjakan.',
              onTap: (v) => setState(() => _metode = v),
            ),
            _MethodOption(
              value: 'manual',
              group: _metode,
              title: 'Manual',
              subtitle: 'Persentase tetap per orang, diatur sendiri.',
              onTap: (v) => setState(() => _metode = v),
            ),

            if (_metode == 'manual') ...[
              const SizedBox(height: AppSpacing.xs),
              const Divider(),
              const SizedBox(height: AppSpacing.xs),
              for (final t in techs)
                _PercentRow(
                  label: t.nama,
                  controller: _shares[t.id]!,
                  onChanged: _touch,
                ),
              _Remaining(sisa: _sisaTeknisi),
            ],

            const SizedBox(height: AppSpacing.s),
            FilledButton(
              onPressed: (_busy || _sisaPeran != 0) ? null : _save,
              child: Text(
                _sisaPeran == 0 ? 'SIMPAN ATURAN' : 'TOTAL HARUS 100%',
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _touch() => setState(() {});
}

class _PercentRow extends StatelessWidget {
  const _PercentRow({
    required this.label,
    required this.controller,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 76,
            child: TextField(
              controller: controller,
              textAlign: TextAlign.right,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                suffixText: '%',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
              ),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              onChanged: (_) => onChanged(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Penunjuk sisa persen. Inilah yang membuat pengaturan manual bisa
/// dilakukan tanpa menebak-nebak.
class _Remaining extends StatelessWidget {
  const _Remaining({required this.sisa});

  final double sisa;

  @override
  Widget build(BuildContext context) {
    final pas = sisa == 0;
    final warna = pas ? AppColors.blue : AppColors.red;

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.06),
        border: Border(left: BorderSide(color: warna, width: 3)),
      ),
      child: Row(
        children: [
          Icon(pas ? Icons.check : Icons.priority_high, size: 13, color: warna),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              pas
                  ? 'Pas 100%'
                  : sisa < 0
                      ? 'Kelebihan ${sisa.abs().toStringAsFixed(0)}%'
                      : 'Sisa ${sisa.toStringAsFixed(0)}% belum dialokasikan',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: warna,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodOption extends StatelessWidget {
  const _MethodOption({
    required this.value,
    required this.group,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.recommended = false,
  });

  final String value;
  final String group;
  final String title;
  final String subtitle;
  final ValueChanged<String> onTap;
  final bool recommended;

  @override
  Widget build(BuildContext context) {
    final active = value == group;

    return InkWell(
      onTap: () => onTap(value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 5),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: active ? AppColors.lightGrey : Colors.transparent,
          border: Border.all(
            color: active ? AppColors.black : const Color(0xFFE4E7E7),
          ),
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 2),
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: active ? AppColors.red : AppColors.grey,
                  width: active ? 4 : 1.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (recommended) ...[
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          color: AppColors.red,
                          child: const Text(
                            'SARAN',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: AppColors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.35,
                      color: AppColors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardMessage extends StatelessWidget {
  const _CardMessage(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.grey, fontSize: 12),
          ),
        ),
      );
}
