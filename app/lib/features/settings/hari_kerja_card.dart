import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/data/galat.dart';
import '../../core/hari_laporan.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/bento.dart';
import '../../core/widgets/swiss_widgets.dart';

final _jam = DateFormat('HH:mm');
final _tglPanjang = DateFormat('EEEE, d MMMM yyyy', 'id');

/// Jam laporan harian ditutup.
///
/// Hari di toko tidak berganti tengah malam. Laporannya ditutup sore dan
/// dikirim ke pusat; unit yang masuk sesudahnya tidak mungkin ikut di
/// dalamnya, jadi ia tercatat sebagai unit hari berikutnya.
///
/// Kartunya sendiri, bukan digabung ke Identitas Toko: yang di sana
/// menentukan bunyi kertas nota, yang di sini menentukan sebuah nota
/// masuk ke laporan hari yang mana. Ditaruh berdampingan, yang kedua akan
/// terbaca seperti keterangan jam buka.
class HariKerjaCard extends ConsumerStatefulWidget {
  const HariKerjaCard({super.key});

  @override
  ConsumerState<HariKerjaCard> createState() => _HariKerjaCardState();
}

class _HariKerjaCardState extends ConsumerState<HariKerjaCard> {
  int? _pilihan;
  bool _busy = false;

  Future<void> _simpan(int jam) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(supabaseProvider)
          .from('store_settings')
          .update({
            'tutup_jam': jam,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', 1);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            jam >= 24
                ? 'Hari kerja mengikuti hari kalender, tanpa pergeseran.'
                : 'Laporan harian ditutup jam $jam.00.',
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
    final tersimpan = ref.watch(jamTutupProvider);
    final jam = _pilihan ?? tersimpan;

    final sekarang = DateTime.now();
    final hariIni = hariLaporan(sekarang, jam);
    final bergeser = hariIni.day != sekarang.day;

    return BentoCard(
      title: 'Hari Kerja',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            LabeledField(
              label: 'Laporan Harian Ditutup',
              hint:
                  'Nota yang masuk pada jam ini atau sesudahnya dihitung '
                  'sebagai nota hari berikutnya — sama seperti buku catatan '
                  'di meja depan.',
              child: DropdownButtonFormField<int>(
                initialValue: jam,
                isExpanded: true,
                items: [
                  for (var j = 12; j <= 24; j++)
                    DropdownMenuItem(
                      value: j,
                      child: Text(
                        j >= 24
                            ? 'Tengah malam — tidak digeser'
                            : '$j.00 — nota sesudahnya masuk besok',
                      ),
                    ),
                ],
                onChanged: _busy ? null : (v) => setState(() => _pilihan = v),
              ),
            ),
            const SizedBox(height: AppSpacing.s),

            // Contohnya dihitung dari jam sekarang, bukan dikarang. Aturan
            // yang cuma dijelaskan dengan kalimat mudah dibaca terbalik --
            // "sesudah jam 17 masuk besok" bisa dikira "masih hari ini
            // sampai jam 17 besok".
            Container(
              padding: const EdgeInsets.all(AppSpacing.s),
              decoration: const BoxDecoration(
                color: Color(0x0D0033A0),
                border: Border(
                  left: BorderSide(color: context.warna.aksen, width: 3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sekarang jam ${_jam.format(sekarang)}.',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: context.warna.aksen,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    bergeser
                        ? 'Nota yang dibuat sekarang masuk laporan '
                              '${_tglPanjang.format(hariIni)} — laporan hari '
                              'ini sudah ditutup.'
                        : 'Nota yang dibuat sekarang masuk laporan '
                              '${_tglPanjang.format(hariIni)}.',
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: context.warna.aksen,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s),

            Text(
              'Berlaku untuk halaman Servis, tab Harian, dan ekspor Excel. '
              'Tanggal selesai dan tanggal lunas ikut memakainya sejak '
              'disimpan — nota yang sudah tercatat tidak digeser.',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: AppSpacing.s),

            FilledButton(
              onPressed: _busy || jam == tersimpan ? null : () => _simpan(jam),
              child: Text(_busy ? 'MENYIMPAN…' : 'SIMPAN JAM TUTUP'),
            ),
          ],
        ),
      ),
    );
  }
}
