import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/models.dart';
import '../../core/kaca/overlay_kaca.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import 'perubahan_nota.dart';

enum HasilSimpanTerkunci { tersimpan, diajukan, dibatalkan }

/// Menyimpan isi formulir nota yang sudah keluar.
///
/// Server yang memilah: catatan dan pelunasan langsung tersimpan, sisanya
/// baru jadi permintaan setelah admin menulis alasannya. Admin melihat dulu
/// apa saja yang akan diajukan, supaya tidak ada perubahan yang terkirim
/// tanpa sengaja.
Future<HasilSimpanTerkunci> simpanNotaTerkunci(
  BuildContext context,
  WidgetRef ref,
  String notaId,
  Map<String, dynamic> data,
) async {
  final db = ref.read(databaseProvider);
  final hasil = await db.ajukanPerubahanNota(notaId, data);
  if (hasil['status'] != 'perlu_alasan') return HasilSimpanTerkunci.tersimpan;

  final baris = barisPerubahan(
    perubahan: Map<String, dynamic>.from(hasil['perubahan'] as Map),
    sebelum: Map<String, dynamic>.from(hasil['sebelum'] as Map),
    namaOrang: {
      for (final p
          in ref.read(allProfilesProvider).valueOrNull ?? const <Profile>[])
        p.id: p.nama,
    },
    namaMetode: {
      for (final m
          in ref.read(allMetodeBayarProvider).valueOrNull ??
              const <MetodeBayar>[])
        m.kode: m.nama,
    },
  );
  if (!context.mounted) return HasilSimpanTerkunci.dibatalkan;

  final alasan = await tampilkanDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DialogAlasan(baris: baris),
  );
  if (alasan == null) return HasilSimpanTerkunci.dibatalkan;

  await db.ajukanPerubahanNota(notaId, data, alasan: alasan);
  return HasilSimpanTerkunci.diajukan;
}

class _DialogAlasan extends StatefulWidget {
  const _DialogAlasan({required this.baris});

  final List<BarisPerubahan> baris;

  @override
  State<_DialogAlasan> createState() => _DialogAlasanState();
}

class _DialogAlasanState extends State<_DialogAlasan> {
  final _alasan = TextEditingController();

  @override
  void dispose() {
    _alasan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final terisi = _alasan.text.trim().isNotEmpty;

    return AlertDialog(
      title: const Text('Ajukan ke super admin'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Nota ini sudah keluar. Perubahan berikut baru berlaku setelah '
                'disetujui.',
              ),
              const SizedBox(height: AppSpacing.s),
              for (final b in widget.baris)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${b.label}: ',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(text: '${b.sebelum} → ${b.sesudah}'),
                      ],
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              const SizedBox(height: AppSpacing.xs),
              TextField(
                controller: _alasan,
                autofocus: true,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Alasan perubahan',
                  hintText: 'Salah ketik biaya saat kasir ramai',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('BATAL'),
        ),
        FilledButton(
          onPressed: terisi
              ? () => Navigator.of(context).pop(_alasan.text.trim())
              : null,
          child: const Text('AJUKAN'),
        ),
      ],
    );
  }
}
