import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/data/galat.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/bento.dart';
import '../../core/widgets/swiss_widgets.dart';

/// [daftar] ditambah [nama], atau [FormatException] berisi alasan yang bisa
/// dibaca kalau namanya tidak bisa diterima.
///
/// Fungsi murni, terpisah dari kartunya, supaya aturannya bisa diuji tanpa
/// menggambar layar.
List<String> cabangDitambah(List<String> daftar, String nama) {
  // Spasi ganda dan spasi di ujung dirapikan: "Pangkalan  Bun" dan
  // "Pangkalan Bun" terlihat sama di layar tetapi dua teks berbeda, dan yang
  // kedua akan lolos sebagai cabang baru.
  final n = nama.trim().replaceAll(RegExp(r'\s+'), ' ');

  if (n.isEmpty) throw const FormatException('Nama cabang belum diisi.');
  if (n.length > 40) {
    throw const FormatException('Nama cabang terlalu panjang (maksimal 40).');
  }
  if (daftar.any((c) => c.toLowerCase() == n.toLowerCase())) {
    throw FormatException('$n sudah ada di daftar.');
  }
  if (daftar.length >= 30) {
    throw const FormatException('Daftar cabang sudah penuh (maksimal 30).');
  }
  return [...daftar, n];
}

/// Daftar cabang tujuan pengiriman unit.
///
/// Ada di Pengaturan, bukan dikunci di kode: cabang bisa bertambah, dan yang
/// menambahkannya orang yang berdiri di toko -- bukan yang bisa membangun
/// ulang aplikasi.
///
/// Nota menyalin nama cabangnya sebagai teks. Cabang yang dihapus dari daftar
/// tidak mengubah nota yang sudah terlanjur dikirim ke sana.
class CabangCard extends ConsumerWidget {
  const CabangCard({super.key});

  Future<void> _simpan(
    BuildContext context,
    WidgetRef ref,
    List<String> baru,
  ) async {
    final pesan = ScaffoldMessenger.of(context);
    try {
      final hasil = await ref
          .read(supabaseProvider)
          .from('store_settings')
          .update({
            'cabang': baru,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', 1)
          .select('id');

      // Aturan akses yang menolak tidak melempar galat; ia hanya tidak
      // mengubah satu baris pun. Tanpa pemeriksaan ini penyimpanan yang
      // ditolak terlihat seperti berhasil.
      if (hasil.isEmpty) {
        pesan.showSnackBar(
          const SnackBar(
            content: Text(
              'Tidak tersimpan. Hanya admin yang boleh mengubah daftar '
              'cabang.',
            ),
          ),
        );
      }
    } on PostgrestException catch (e) {
      pesan.showSnackBar(SnackBar(content: Text(pesanGalat(e))));
    } catch (_) {
      pesan.showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan. Perlu koneksi.')),
      );
    }
  }

  Future<void> _tambah(
    BuildContext context,
    WidgetRef ref,
    List<String> daftar,
  ) async {
    final nama = TextEditingController();
    String? galat;

    final baru = await showDialog<List<String>>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          void kirim() {
            try {
              Navigator.of(context).pop(cabangDitambah(daftar, nama.text));
            } on FormatException catch (e) {
              setState(() => galat = e.message);
            }
          }

          return AlertDialog(
            backgroundColor: context.warna.permukaan,
            title: Text(
              'TAMBAH CABANG',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            content: SizedBox(
              width: 340,
              child: LabeledField(
                label: 'Nama Cabang',
                hint: 'Yang muncul di pilihan saat unit dikirim.',
                child: TextField(
                  controller: nama,
                  autofocus: true,
                  onSubmitted: (_) => kirim(),
                  decoration: InputDecoration(
                    hintText: 'Kotawaringin Lama',
                    errorText: galat,
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('BATAL'),
              ),
              FilledButton(onPressed: kirim, child: const Text('TAMBAH')),
            ],
          );
        },
      ),
    );
    nama.dispose();

    if (baru != null && context.mounted) await _simpan(context, ref, baru);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daftar = ref.watch(cabangProvider);

    return BentoCard(
      title: 'Cabang',
      padding: EdgeInsets.zero,
      trailing: InlineAction(
        label: 'Tambah',
        onTap: () => _tambah(context, ref, daftar),
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
              decoration: BoxDecoration(
                color: context.warna.aksen.withValues(alpha: 0.05),
                border: Border(
                  left: BorderSide(color: context.warna.aksen, width: 3),
                ),
              ),
              child: Text(
                'Pilihan di status "Dikirim ke Cabang". Menghapus cabang dari '
                'sini tidak mengubah nota yang sudah dikirim ke sana.',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.4,
                  color: context.warna.aksen,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          Expanded(
            child: daftar.isEmpty
                ? Center(
                    child: Text(
                      'Belum ada cabang.',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    itemCount: daftar.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, i) => Row(
                      children: [
                        Expanded(
                          child: Text(
                            daftar[i],
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Hapus ${daftar[i]}',
                          icon: const Icon(Icons.close, size: 16),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _simpan(context, ref, [
                            for (var j = 0; j < daftar.length; j++)
                              if (j != i) daftar[j],
                          ]),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
