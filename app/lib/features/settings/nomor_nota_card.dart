import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/kaca/overlay_kaca.dart';
import '../../core/nota/nomor_nota.dart';
import '../../core/data/galat.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/bento.dart';
import '../../core/widgets/swiss_widgets.dart';

/// Nomor yang akan dipakai nota berikutnya, dibaca langsung dari server.
///
/// Sengaja tidak ikut dicerminkan ke basis data lokal. Angka ini berubah
/// setiap kali ada nota baru terbit dari komputer mana pun; salinan lokal
/// yang tertinggal beberapa menit justru menyesatkan pada satu-satunya
/// layar yang dipakai orang untuk memutuskan menggesernya.
final nomorNotaBerikutnyaProvider = FutureProvider.autoDispose<int>((
  ref,
) async {
  final hasil = await ref.watch(supabaseProvider).rpc('nomor_nota_berikutnya');
  return (hasil as num).toInt();
});

/// Menggeser nomor urut nota.
///
/// Dibutuhkan saat nomornya perlu disambungkan ke catatan pusat yang sudah
/// berjalan, atau saat ada nota telanjur terbit dengan nomor keliru.
class NomorNotaCard extends ConsumerStatefulWidget {
  const NomorNotaCard({super.key});

  @override
  ConsumerState<NomorNotaCard> createState() => _NomorNotaCardState();
}

class _NomorNotaCardState extends ConsumerState<NomorNotaCard> {
  final _nomor = TextEditingController();

  int? _tersimpan;
  bool _busy = false;

  @override
  void dispose() {
    _nomor.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    final n = int.tryParse(_nomor.text);
    if (n == null || n < 1) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nomor harus 1 atau lebih')));
      return;
    }

    // Menurunkan nomor berarti angka yang sudah terpakai akan terbit lagi.
    // Nota lama tidak tertimpa -- tanggal di depan nomor membuatnya tetap
    // berbeda -- tetapi pusat membaca 5 digit terakhirnya saja, dan di
    // sana keduanya akan tampak sebagai nota yang sama.
    if (_tersimpan != null && n < _tersimpan!) {
      final lanjut = await tampilkanDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Mundurkan nomor nota?'),
          content: Text(
            'Nomor sekarang $_tersimpan, akan dimundurkan ke $n.\n\n'
            'Angka $n sampai ${_tersimpan! - 1} akan terbit untuk kedua '
            'kalinya. Pusat membaca 5 digit terakhir nomor nota, jadi nota '
            'baru itu akan terbaca sama dengan nota yang sudah dilaporkan.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('BATAL'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('TETAP MUNDURKAN'),
            ),
          ],
        ),
      );
      if (lanjut != true) return;
    }

    setState(() => _busy = true);
    try {
      await ref
          .read(supabaseProvider)
          .rpc('set_nomor_nota_berikutnya', params: {'nomor': n});

      ref.invalidate(nomorNotaBerikutnyaProvider);
      setState(() => _tersimpan = n);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Nota berikutnya: ${contohNomorNota(n, DateTime.now())}',
          ),
        ),
      );
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
    final berikutnya = ref.watch(nomorNotaBerikutnyaProvider);

    berikutnya.whenData((n) {
      if (_tersimpan == null) {
        _tersimpan = n;
        _nomor.text = n.toString();
      }
    });

    final calon = int.tryParse(_nomor.text);

    return BentoCard(
      title: 'Nomor Nota',
      trailing: IconButton(
        tooltip: 'Muat ulang',
        iconSize: 17,
        onPressed: _busy
            ? null
            : () {
                _tersimpan = null;
                ref.invalidate(nomorNotaBerikutnyaProvider);
              },
        icon: const Icon(Icons.refresh),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _Papan(nilai: berikutnya),
            const SizedBox(height: AppSpacing.s),

            LabeledField(
              label: 'Nomor Nota Berikutnya',
              hint:
                  'Angka yang akan dipakai nota yang terbit sesudah ini — '
                  'bukan nomor terakhir yang sudah terpakai.',
              child: TextField(
                controller: _nomor,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  helperText: calon == null || calon < 1
                      ? 'Contoh: 28177'
                      : 'Terbit sebagai '
                            '${contohNomorNota(calon, DateTime.now())}',
                  helperStyle: TextStyle(
                    fontSize: 10.5,
                    color: context.warna.teksLembut,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: AppSpacing.s),

            Container(
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: BoxDecoration(
                color: context.warna.aksen.withValues(alpha: 0.05),
                border: Border(
                  left: BorderSide(color: context.warna.aksen, width: 3),
                ),
              ),
              child: Text(
                'Pusat membaca 5 digit terakhir nomor nota sebagai jumlah '
                'nota yang pernah dibuat. Setel angka ini menyambung catatan '
                'pusat supaya laporan harian tidak mengulang dari awal.',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.4,
                  color: context.warna.aksen,
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.sm),
            FilledButton(
              onPressed: _busy || berikutnya.isLoading ? null : _simpan,
              child: const Text('SIMPAN NOMOR NOTA'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nomor yang berlaku sekarang, ditampilkan besar supaya bisa dicocokkan
/// dengan nota di tangan tanpa perlu membaca teks kecil.
class _Papan extends StatelessWidget {
  const _Papan({required this.nilai});

  final AsyncValue<int> nilai;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.s,
      ),
      color: context.warna.teredam,
      child: nilai.when(
        loading: () => Text(
          'Memuat…',
          style: TextStyle(fontSize: 13, color: context.warna.teksLembut),
        ),
        error: (_, _) => Text(
          'Tidak terbaca. Nomor nota hanya bisa dilihat dan diubah saat '
          'tersambung ke server.',
          style: TextStyle(fontSize: 11.5, height: 1.4, color: context.warna.bahaya),
        ),
        data: (n) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NOTA BERIKUTNYA',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 4),
            Text(
              contohNomorNota(n, DateTime.now()),
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              n <= 1
                  ? 'Belum ada nota yang terbit'
                  : '${n - 1} nota sudah terpakai menurut hitungan ini',
              style: TextStyle(fontSize: 11, color: context.warna.teksLembut),
            ),
          ],
        ),
      ),
    );
  }
}
