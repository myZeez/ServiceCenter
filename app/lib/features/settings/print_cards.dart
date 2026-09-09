import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/print/nota_template.dart';
import '../../core/print/raw_printer.dart';
import '../../core/data/galat.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/bento.dart';
import '../../core/widgets/swiss_widgets.dart';

// =====================================================================
// Printer nota
// =====================================================================

class PrinterCard extends ConsumerStatefulWidget {
  const PrinterCard({super.key});

  @override
  ConsumerState<PrinterCard> createState() => _PrinterCardState();
}

class _PrinterCardState extends ConsumerState<PrinterCard> {
  List<String>? _daftar;
  String? _dipilih;
  final _lebar = TextEditingController();
  bool _terisi = false;
  String? _pesan;

  @override
  void initState() {
    super.initState();
    _daftar = RawPrinter.daftar();
  }

  @override
  void dispose() {
    _lebar.dispose();
    super.dispose();
  }

  Future<void> _uji() async {
    final lebar = int.tryParse(_lebar.text) ?? 32;
    final galat = RawPrinter.kirim(_dipilih ?? '', susunUjiCetak(lebar: lebar));
    setState(() => _pesan = galat ?? 'Uji cetak terkirim.');
  }

  @override
  Widget build(BuildContext context) {
    final nama = ref.watch(printerNamaProvider).valueOrNull;
    final lebar = ref.watch(printerLebarProvider).valueOrNull;

    if (!_terisi && nama != null && lebar != null) {
      _dipilih = nama.isEmpty ? null : nama;
      _lebar.text = '$lebar';
      _terisi = true;
    }

    if (!RawPrinter.didukung) {
      return const BentoCard(
        title: 'Printer Nota',
        child: Text(
          'Cetak nota hanya tersedia di aplikasi Windows, tempat printernya '
          'terpasang.',
          style: TextStyle(fontSize: 12, color: AppColors.grey),
        ),
      );
    }

    final daftar = _daftar ?? const <String>[];

    return BentoCard(
      title: 'Printer Nota',
      trailing: InlineAction(
        label: 'Cari ulang',
        onTap: () => setState(() => _daftar = RawPrinter.daftar()),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (daftar.isEmpty)
              const Text(
                'Tidak ada printer terdeteksi di komputer ini.',
                style: TextStyle(fontSize: 12, color: AppColors.red),
              )
            else
              LabeledField(
                label: 'Printer',
                child: DropdownButtonFormField<String>(
                  initialValue: daftar.contains(_dipilih) ? _dipilih : null,
                  isExpanded: true,
                  hint: const Text('Pilih printer'),
                  items: [
                    for (final p in daftar)
                      DropdownMenuItem(value: p, child: Text(p)),
                  ],
                  onChanged: (v) => setState(() => _dipilih = v),
                ),
              ),
            const SizedBox(height: AppSpacing.s),
            LabeledField(
              label: 'Lebar Kolom',
              hint:
                  'Jumlah karakter per baris. Kertas 57,5mm biasanya 32 — '
                  'pastikan lewat uji cetak, garis penggarisnya harus pas '
                  'satu baris.',
              child: TextField(
                controller: _lebar,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(suffixText: 'karakter'),
              ),
            ),
            if (_pesan != null) ...[
              const SizedBox(height: AppSpacing.s),
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: 0.06),
                  border: const Border(
                    left: BorderSide(color: AppColors.blue, width: 3),
                  ),
                ),
                child: Text(
                  _pesan!,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: AppColors.blue,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.s),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _dipilih == null ? null : _uji,
                    child: const Text('UJI CETAK'),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: FilledButton(
                    onPressed: _dipilih == null
                        ? null
                        : () async {
                            await simpanPrinter(
                              ref,
                              _dipilih!,
                              int.tryParse(_lebar.text) ?? 32,
                            );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Pengaturan printer tersimpan'),
                              ),
                            );
                          },
                    child: const Text('SIMPAN'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// Identitas toko
// =====================================================================

class StoreCard extends ConsumerStatefulWidget {
  const StoreCard({super.key});

  @override
  ConsumerState<StoreCard> createState() => _StoreCardState();
}

class _StoreCardState extends ConsumerState<StoreCard> {
  final _nama = TextEditingController();
  final _alamat = TextEditingController();
  final _telepon = TextEditingController();
  final _ketentuan = TextEditingController();

  bool _terisi = false;
  bool _busy = false;

  @override
  void dispose() {
    _nama.dispose();
    _alamat.dispose();
    _telepon.dispose();
    _ketentuan.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(supabaseProvider)
          .from('store_settings')
          .update({
            'nama': _nama.text.trim(),
            'alamat': _alamat.text.trim().isEmpty ? null : _alamat.text.trim(),
            'telepon': _telepon.text.trim().isEmpty
                ? null
                : _telepon.text.trim(),
            'ketentuan': _ketentuan.text.trim().isEmpty
                ? null
                : _ketentuan.text.trim(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', 1);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Identitas toko tersimpan')));
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(pesanGalat(e))));
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
    final toko = ref.watch(storeSettingsProvider).valueOrNull;

    if (!_terisi && toko != null) {
      _nama.text = toko.nama;
      _alamat.text = toko.alamat ?? '';
      _telepon.text = toko.telepon ?? '';
      _ketentuan.text = toko.ketentuan ?? '';
      _terisi = true;
    }

    return BentoCard(
      title: 'Identitas Toko',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            LabeledField(
              label: 'Nama Toko',
              child: TextField(
                controller: _nama,
                textCapitalization: TextCapitalization.characters,
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            LabeledField(
              label: 'Alamat',
              child: TextField(controller: _alamat, maxLines: 2),
            ),
            const SizedBox(height: AppSpacing.s),
            LabeledField(
              label: 'Telepon',
              child: TextField(controller: _telepon),
            ),
            const SizedBox(height: AppSpacing.s),
            LabeledField(
              label: 'Ketentuan Nota',
              hint:
                  'Dicetak di kaki nota. Tiap baris baru tetap jadi baris '
                  'terpisah saat dicetak.',
              child: TextField(
                controller: _ketentuan,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Barang yang tidak diambil dalam 30 hari...',
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            FilledButton(
              onPressed: _busy ? null : _simpan,
              child: const Text('SIMPAN IDENTITAS'),
            ),
          ],
        ),
      ),
    );
  }
}
