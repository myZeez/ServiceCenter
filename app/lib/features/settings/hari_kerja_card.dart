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

/// Jam nota keluar ditutup.
///
/// Laporan nota keluar ditutup sore dan dikirim ke pusat; unit yang
/// selesai atau dilunasi sesudahnya tidak mungkin ikut di dalamnya, jadi
/// ia tercatat di laporan hari berikutnya.
///
/// Nota masuk tidak ikut bergeser. Unit yang diterima jam berapa pun
/// sampai 23.59 tercatat di hari itu juga, sama seperti di buku meja
/// depan -- menerima barang tidak ada hubungannya dengan tutup buku.
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
                : 'Nota keluar ditutup jam $jam.00.',
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
    final hariKeluar = hariLaporan(sekarang, jam);
    final bergeser = hariKeluar.day != sekarang.day;

    return BentoCard(
      title: 'Hari Kerja',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            LabeledField(
              label: 'Nota Keluar Ditutup',
              hint:
                  'Unit yang selesai atau dilunasi pada jam ini atau '
                  'sesudahnya masuk laporan keluar hari berikutnya. Nota '
                  'masuk tidak digeser — tetap tercatat di hari diterimanya.',
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
                            : '$j.00 — yang keluar sesudahnya masuk besok',
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
              decoration: BoxDecoration(
                color: context.warna.aksen.withValues(alpha: 0.05),
                border: Border(
                  left: BorderSide(color: context.warna.aksen, width: 3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sekarang jam ${_jam.format(sekarang)}.',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: context.warna.aksen,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Unit yang masuk sekarang: laporan '
                    '${_tglPanjang.format(sekarang)}.\n'
                    'Unit yang selesai sekarang: laporan '
                    '${_tglPanjang.format(hariKeluar)}'
                    '${bergeser ? ' — laporan keluar hari ini sudah ditutup.' : '.'}',
                    style: TextStyle(
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
              'Berlaku untuk nota keluar di tab Harian dan ekspor Excel, '
              'dan untuk tanggal lunas di laporan Pelunasan. Nota yang '
              'sudah tercatat tidak digeser.',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: AppSpacing.s),

            FilledButton(
              onPressed: _busy || jam == tersimpan ? null : () => _simpan(jam),
              child: Text(_busy ? 'MENYIMPAN…' : 'SIMPAN JAM TUTUP'),
            ),

            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.sm),

            _HariLibur(busy: _busy),
          ],
        ),
      ),
    );
  }
}

/// Hari toko tutup.
///
/// Di sini, bukan di dalam kode: hari libur bergeser -- libur nasional,
/// cuti bersama, atau keputusan baru -- dan yang mengubahnya orang yang
/// sedang berdiri di toko.
class _HariLibur extends ConsumerStatefulWidget {
  const _HariLibur({required this.busy});

  final bool busy;

  @override
  ConsumerState<_HariLibur> createState() => _HariLiburState();
}

class _HariLiburState extends ConsumerState<_HariLibur> {
  /// Nomor hari ISO, sama seperti DateTime.weekday.
  static const _nama = {
    DateTime.monday: 'SEN',
    DateTime.tuesday: 'SEL',
    DateTime.wednesday: 'RAB',
    DateTime.thursday: 'KAM',
    DateTime.friday: 'JUM',
    DateTime.saturday: 'SAB',
    DateTime.sunday: 'MIN',
  };

  Set<int>? _pilihan;
  bool _busy = false;

  Future<void> _simpan(Set<int> hari) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(supabaseProvider)
          .from('store_settings')
          .update({
            'hari_libur': hari.toList()..sort(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', 1);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hari.isEmpty
                ? 'Toko buka setiap hari.'
                : 'Libur setiap ${_kalimat(hari)}.',
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

  static String _kalimat(Set<int> hari) {
    const panjang = {
      DateTime.monday: 'Senin',
      DateTime.tuesday: 'Selasa',
      DateTime.wednesday: 'Rabu',
      DateTime.thursday: 'Kamis',
      DateTime.friday: 'Jumat',
      DateTime.saturday: 'Sabtu',
      DateTime.sunday: 'Minggu',
    };
    final urut = hari.toList()..sort();
    return [for (final h in urut) panjang[h]!].join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final tersimpan = ref.watch(hariLiburProvider);
    final pilihan = _pilihan ?? tersimpan;
    final sama =
        pilihan.length == tersimpan.length && pilihan.containsAll(tersimpan);
    final sibuk = _busy || widget.busy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        LabeledField(
          label: 'Hari Libur',
          hint:
              'Laporan harian menandainya libur, dan ekspor Excel bulanan '
              'tidak menerbitkan tabnya sama sekali — sama seperti berkas '
              'SVS yang dikirim ke pusat.',
          child: Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final e in _nama.entries)
                _ChipHari(
                  label: e.value,
                  aktif: pilihan.contains(e.key),
                  onTap: sibuk
                      ? null
                      : () => setState(() {
                          final baru = {...pilihan};
                          if (!baru.remove(e.key)) baru.add(e.key);
                          _pilihan = baru;
                        }),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        Text(
          pilihan.isEmpty
              ? 'Tidak ada hari libur — toko dianggap buka setiap hari.'
              : 'Libur setiap ${_kalimat(pilihan)}.',
          style: Theme.of(context).textTheme.labelSmall,
        ),
        const SizedBox(height: AppSpacing.s),
        FilledButton(
          onPressed: sibuk || sama ? null : () => _simpan(pilihan),
          child: Text(_busy ? 'MENYIMPAN…' : 'SIMPAN HARI LIBUR'),
        ),
      ],
    );
  }
}

class _ChipHari extends StatelessWidget {
  const _ChipHari({
    required this.label,
    required this.aktif,
    required this.onTap,
  });

  final String label;
  final bool aktif;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.small),
      child: Container(
        width: 52,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: aktif ? context.warna.bahaya : context.warna.permukaan,
          border: Border.all(
            color: aktif ? context.warna.bahaya : context.warna.garisIsian,
          ),
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: aktif ? context.warna.permukaan : context.warna.teks,
          ),
        ),
      ),
    );
  }
}
