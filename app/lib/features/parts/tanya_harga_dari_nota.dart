import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/models.dart';
import '../../core/kaca/overlay_kaca.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import 'part_dialog.dart';
import 'part_status.dart';

/// Nomor nota per id, sekali hitung. Baris tanya harga memakainya untuk
/// menyebut nota asalnya tanpa mencari di ribuan nota tiap kali dilukis.
final noNotaPerIdProvider = Provider<Map<String, String>>((ref) {
  return {
    for (final n
        in ref.watch(serviceOrdersProvider).valueOrNull ??
            const <ServiceOrderEntry>[])
      n.id: n.noNota,
  };
});

/// Nomor nota asal sebuah tanya harga, kecil di bawah nama pelanggan.
class NomorNotaTanyaHarga extends ConsumerWidget {
  const NomorNotaTanyaHarga(this.notaId, {super.key});

  final String? notaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final no = notaId == null ? null : ref.watch(noNotaPerIdProvider)[notaId];
    if (no == null) return const SizedBox.shrink();
    return Text(
      no,
      style: Theme.of(context).textTheme.labelSmall,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Memulai tanya harga dari sebuah nota servis.
///
/// Tanya harga selalu lahir dari nota: pelanggan, unit, SN, dan teknisinya
/// dibawa dari sana, seperti klaim garansi. Satu nota satu tanya harga;
/// kalau sudah ada, yang dibuka adalah yang itu, bukan yang kedua.
Future<void> mulaiTanyaHarga(
  BuildContext context,
  WidgetRef ref,
  ServiceOrderEntry nota,
) {
  final ada = ref.read(tanyaHargaNotaProvider(nota.id));
  return showPartDialog(
    context,
    pesanan: ada,
    awal: ada == null ? AwalTanyaHarga.dariNota(nota) : null,
  );
}

/// Memilih nota, lalu membuka tanya harganya.
Future<void> tanyaHargaDariNota(BuildContext context, WidgetRef ref) async {
  final nota = await tampilkanDialog<ServiceOrderEntry>(
    context: context,
    builder: (_) => const PilihNotaTanyaHarga(),
  );
  if (nota == null || !context.mounted) return;
  await mulaiTanyaHarga(context, ref, nota);
}

/// Nota yang masih layak ditanyakan part-nya: yang dibatalkan tidak lagi
/// butuh part, dan pencarian dibatasi supaya daftar ribuan nota arsip tidak
/// dilukis sekaligus.
List<ServiceOrderEntry> saringNotaTanyaHarga(
  List<ServiceOrderEntry> semua,
  String query, {
  int batas = 40,
}) {
  final q = query.toLowerCase().trim();
  final hasil = <ServiceOrderEntry>[];

  for (final n in semua) {
    if (n.status == 'batal') continue;
    if (q.isNotEmpty &&
        !n.noNota.toLowerCase().contains(q) &&
        !n.customerNama.toLowerCase().contains(q) &&
        !n.barangNama.toLowerCase().contains(q) &&
        !(n.barangSn ?? '').toLowerCase().contains(q)) {
      continue;
    }
    hasil.add(n);
    if (hasil.length >= batas) break;
  }
  return hasil;
}

class PilihNotaTanyaHarga extends ConsumerStatefulWidget {
  const PilihNotaTanyaHarga({super.key});

  @override
  ConsumerState<PilihNotaTanyaHarga> createState() =>
      _PilihNotaTanyaHargaState();
}

class _PilihNotaTanyaHargaState extends ConsumerState<PilihNotaTanyaHarga> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final semua =
        ref.watch(serviceOrdersProvider).valueOrNull ??
        const <ServiceOrderEntry>[];
    final pesanan =
        ref.watch(partOrdersProvider).valueOrNull ?? const <PartOrder>[];
    final sudahAda = {
      for (final p in pesanan)
        if (p.serviceOrderId != null) p.serviceOrderId!: p,
    };
    // Terbaru lebih dulu: nota yang baru masuk yang paling sering ditanyakan.
    final urut = [...semua]
      ..sort((a, b) => b.tanggalMasuk.compareTo(a.tanggalMasuk));
    final tampil = saringNotaTanyaHarga(urut, _query);

    return AlertDialog(
      title: const Text('Pilih nota servis'),
      content: SizedBox(
        width: 480,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Tanya harga dibuat dari nota. Data pelanggan dan unitnya '
              'dibawa dari sana.',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: AppSpacing.s),
            TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Cari nomor nota, nama, barang, SN',
                prefixIcon: Icon(
                  Icons.search,
                  size: 17,
                  color: context.warna.teksLembut,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Expanded(
              child: tampil.isEmpty
                  ? Center(
                      child: Text(
                        'Tidak ada nota yang cocok.',
                        style: TextStyle(color: context.warna.teksLembut),
                      ),
                    )
                  : ListView.separated(
                      itemCount: tampil.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final n = tampil[i];
                        final ada = sudahAda[n.id];
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${n.noNota}  ·  ${n.customerNama}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            [
                              n.barangNama,
                              if ((n.barangSn ?? '').isNotEmpty) n.barangSn!,
                            ].join('  ·  '),
                          ),
                          trailing: ada == null
                              ? null
                              : PartTahapChip(ada.tahap, compact: true),
                          onTap: () => Navigator.of(context).pop(n),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('BATAL'),
        ),
      ],
    );
  }
}
