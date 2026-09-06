import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/galat.dart';
import '../../core/data/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/bento.dart';
import '../../core/widgets/swiss_widgets.dart';

/// Daftar cara pelanggan membayar.
///
/// Ada di Pengaturan, bukan dikunci di kode: rekening dan dompet digital
/// baru muncul jauh lebih sering daripada aplikasi ini dibangun ulang.
class MetodeBayarCard extends ConsumerWidget {
  const MetodeBayarCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metode =
        ref.watch(allMetodeBayarProvider).valueOrNull ?? const <MetodeBayar>[];

    return BentoCard(
      title: 'Cara Bayar',
      padding: EdgeInsets.zero,
      trailing: InlineAction(
        label: 'Tambah',
        onTap: () => _form(context, ref),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.s,
              AppSpacing.sm,
              0,
            ),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: const BoxDecoration(
                color: Color(0x0D0033A0),
                border: Border(
                  left: BorderSide(color: AppColors.blue, width: 3),
                ),
              ),
              child: const Text(
                'Yang ditandai PIUTANG berarti uangnya belum diterima — '
                'notanya tidak dihitung lunas. Tunai, transfer, dan QRIS '
                'sama saja bagi kas toko.',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.4,
                  color: AppColors.blue,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          Expanded(
            child: metode.isEmpty
                ? Center(
                    child: Text(
                      'Belum ada cara bayar.',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    itemCount: metode.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, i) =>
                        _Baris(metode[i], onUbah: () => _form(context, ref, m: metode[i])),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _form(
    BuildContext context,
    WidgetRef ref, {
    MetodeBayar? m,
  }) async {
    final nama = TextEditingController(text: m?.nama ?? '');
    var piutang = m?.piutang ?? false;

    final simpan = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.white,
          title: Text(
            m == null ? 'TAMBAH CARA BAYAR' : 'UBAH CARA BAYAR',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          content: SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LabeledField(
                  label: 'Nama',
                  hint: 'Yang muncul di dropdown dan tercetak di nota.',
                  child: TextField(
                    controller: nama,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Transfer BRI',
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.s),
                CheckboxListTile(
                  value: piutang,
                  onChanged: (v) => setState(() => piutang = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text(
                    'Piutang',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Uangnya belum diterima saat nota ditutup.',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('BATAL'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('SIMPAN'),
            ),
          ],
        ),
      ),
    );

    if (simpan != true || !context.mounted) return;
    final teks = nama.text.trim();
    if (teks.isEmpty) return;

    // Kode dibuat dari namanya, dan hanya untuk baris baru. Nota lama
    // menyimpan kode ini apa adanya; mengubahnya berarti nota yang sudah
    // tercetak tiba-tiba menunjuk ke cara bayar yang tidak ada lagi.
    final kode =
        m?.kode ??
        teks.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');

    try {
      await ref.read(databaseProvider).simpanMetodeBayar({
        if (m != null) 'id': m.id,
        'kode': kode,
        'nama': teks,
        'piutang': piutang,
        'urutan': m?.urutan ?? 50,
        'aktif': m?.aktif ?? true,
      });
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(pesanGalat(e))));
    }
  }
}

class _Baris extends ConsumerWidget {
  const _Baris(this.m, {required this.onUbah});

  final MetodeBayar m;
  final VoidCallback onUbah;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  m.nama,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: m.aktif ? AppColors.black : AppColors.grey,
                  ),
                ),
                Text(
                  m.piutang ? 'PIUTANG' : m.kode,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: m.piutang ? AppColors.red : AppColors.grey,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Ubah',
            iconSize: 16,
            color: AppColors.grey,
            icon: const Icon(Icons.edit_outlined),
            onPressed: onUbah,
          ),
          // Dinonaktifkan, bukan dihapus. Nota lama menyimpan kodenya dan
          // harus tetap bisa menyebutkan namanya bertahun-tahun kemudian.
          IconButton(
            tooltip: m.aktif ? 'Nonaktifkan' : 'Aktifkan lagi',
            iconSize: 16,
            color: m.aktif ? AppColors.grey : AppColors.blue,
            icon: Icon(
              m.aktif ? Icons.visibility_off_outlined : Icons.visibility,
            ),
            onPressed: () async {
              try {
                await ref.read(databaseProvider).simpanMetodeBayar({
                  'id': m.id,
                  'kode': m.kode,
                  'nama': m.nama,
                  'piutang': m.piutang,
                  'urutan': m.urutan,
                  'aktif': !m.aktif,
                });
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(pesanGalat(e))));
              }
            },
          ),
        ],
      ),
    );
  }
}
