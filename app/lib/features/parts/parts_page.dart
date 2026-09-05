import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/data/galat.dart';
import '../../core/data/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/gagal_muat.dart';
import '../../core/widgets/koneksi.dart';
import '../../core/widgets/swiss_widgets.dart';
import 'part_status.dart';

final _rp = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp',
  decimalDigits: 0,
);
final _tgl = DateFormat('dd/MM/yy');

/// Pesanan part di layar sempit.
///
/// Satu halaman untuk kedua tahap, tidak seperti di layar lebar. Yang
/// memisahkan Tanya Harga dari Pemesanan Part di sana adalah kolom-kolom
/// uang; di sini kolom itu memang tidak ditampilkan, jadi memecahnya jadi
/// dua halaman hanya menambah satu ketukan tanpa menambah keterangan.
///
/// Yang bisa diubah teknisi sedikit dan disengaja: keadaan stok, catatan,
/// dan penanda bahwa partnya sudah ia pasang. Harga, DP, dan pelunasan
/// tetap urusan meja depan -- server menolaknya, jadi menampilkan
/// kolomnya di sini hanya akan mengundang orang mengetik sesuatu yang
/// tidak akan pernah tersimpan.
class PartsPage extends ConsumerStatefulWidget {
  const PartsPage({super.key});

  @override
  ConsumerState<PartsPage> createState() => _PartsPageState();
}

class _PartsPageState extends ConsumerState<PartsPage> {
  String? _tahap;

  @override
  Widget build(BuildContext context) {
    final pesanan = ref.watch(partOrdersProvider);
    final techs = {
      for (final p
          in ref.watch(techniciansProvider).valueOrNull ?? const <Profile>[])
        p.id: p.nama,
    };

    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.sm,
        title: const Text('Part'),
        actions: const [IndikatorKoneksi(), SizedBox(width: AppSpacing.xs)],
      ),
      body: Column(
        children: [
          _Saringan(
            dipilih: _tahap,
            jumlah: _perTahap(pesanan.valueOrNull ?? const []),
            onPilih: (t) => setState(() => _tahap = t),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                segarkanData(ref);
                await ref.read(partOrdersProvider.future);
              },
              child: pesanan.when(
                loading: () => const Center(
                  child: SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (e, _) => GagalMuat(e),
                data: (semua) {
                  final tampil = _tahap == null
                      ? semua
                      : semua.where((p) => p.tahap == _tahap).toList();

                  if (tampil.isEmpty) {
                    return ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.55,
                          child: EmptyState(
                            icon: Icons.request_quote_outlined,
                            title: semua.isEmpty
                                ? 'Belum ada pesanan part'
                                : 'Tidak ada yang di tahap ini',
                            description: semua.isEmpty
                                ? 'Dicatat di meja depan saat pelanggan '
                                      'menanyakan harga part.'
                                : 'Pilih tahap lain di atas.',
                          ),
                        ),
                      ],
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    itemCount: tampil.length,
                    itemBuilder: (context, i) =>
                        _Kartu(pesanan: tampil[i], teknisi: techs),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Map<String, int> _perTahap(List<PartOrder> l) {
    final h = <String, int>{};
    for (final p in l) {
      h.update(p.tahap, (v) => v + 1, ifAbsent: () => 1);
    }
    return h;
  }
}

class _Saringan extends StatelessWidget {
  const _Saringan({
    required this.dipilih,
    required this.jumlah,
    required this.onPilih,
  });

  final String? dipilih;
  final Map<String, int> jumlah;
  final ValueChanged<String?> onPilih;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.black)),
      ),
      padding: const EdgeInsets.only(bottom: AppSpacing.s),
      child: SizedBox(
        height: 34,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          children: [
            _Chip(
              label: 'SEMUA',
              aktif: dipilih == null,
              onTap: () => onPilih(null),
            ),
            for (final t in PartTahap.all)
              if ((jumlah[t] ?? 0) > 0)
                _Chip(
                  label: '${PartTahap.label(t).toUpperCase()}  ${jumlah[t]}',
                  aktif: dipilih == t,
                  onTap: () => onPilih(t),
                ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.aktif, required this.onTap});

  final String label;
  final bool aktif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: aktif ? AppColors.black : AppColors.white,
            border: Border.all(color: AppColors.black),
            borderRadius: BorderRadius.circular(AppRadius.small),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: aktif ? AppColors.white : AppColors.black,
            ),
          ),
        ),
      ),
    );
  }
}

class _Kartu extends ConsumerWidget {
  const _Kartu({required this.pesanan, required this.teknisi});

  final PartOrder pesanan;
  final Map<String, String> teknisi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = pesanan;

    return InkWell(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.white,
        builder: (_) => _UbahPart(pesanan: p),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.s,
        ),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFE4E7E7))),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: PartStokLabel(p.stok)),
                PartTahapChip(p.tahap, compact: true),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              p.customerNama,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              p.partReq,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
            if ((p.barangType ?? '').isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                p.barangType!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, color: AppColors.grey),
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  '${_tgl.format(p.tanggal)}  ·  '
                  '${teknisi[p.teknisiId] ?? 'belum ada teknisi'}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const Spacer(),
                // Harga jual boleh dilihat semua orang -- itu angka yang
                // disebutkan kepada pelanggan. Modal dan marginnya tidak
                // pernah sampai ke perangkat ini.
                if (p.harga != null)
                  Text(
                    _rp.format(p.harga),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
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

class _UbahPart extends ConsumerStatefulWidget {
  const _UbahPart({required this.pesanan});

  final PartOrder pesanan;

  @override
  ConsumerState<_UbahPart> createState() => _UbahPartState();
}

class _UbahPartState extends ConsumerState<_UbahPart> {
  late String? _stok = widget.pesanan.stok;
  late String _tahap = widget.pesanan.tahap;
  late final _catatan = TextEditingController(
    text: widget.pesanan.catatan ?? '',
  );

  bool _busy = false;

  @override
  void dispose() {
    _catatan.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    setState(() => _busy = true);
    try {
      await ref.read(databaseProvider).ubahPartOrder(widget.pesanan.id, {
        'stok': _stok,
        'tahap': _tahap,
        'catatan': _catatan.text.trim().isEmpty ? null : _catatan.text.trim(),
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(pesanGalat(e)),
          duration: const Duration(seconds: 8),
        ),
      );
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Pesanan diperbarui')));
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    final p = widget.pesanan;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.sm,
        right: AppSpacing.sm,
        top: AppSpacing.sm,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(p.partReq, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 2),
          Text(
            p.customerNama,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.sm),

          LabeledField(
            label: 'Stok',
            child: DropdownButtonFormField<String>(
              initialValue: _stok,
              isExpanded: true,
              hint: const Text('Belum dicek'),
              items: [
                for (final s in PartStok.all)
                  DropdownMenuItem(value: s, child: Text(PartStok.label(s))),
              ],
              onChanged: (v) => setState(() => _stok = v),
            ),
          ),
          const SizedBox(height: AppSpacing.s),

          // Teknisi hanya mendapat satu perpindahan: menandai part sudah
          // ia pasang. Dropdown penuh akan menawarkan tahap yang pasti
          // ditolak server, dan penolakan yang bisa diramalkan sebaiknya
          // tidak pernah ditawarkan.
          if (isAdmin)
            LabeledField(
              label: 'Tahap',
              child: DropdownButtonFormField<String>(
                initialValue: _tahap,
                isExpanded: true,
                items: [
                  for (final t in PartTahap.all)
                    DropdownMenuItem(value: t, child: Text(PartTahap.label(t))),
                ],
                onChanged: (v) => setState(() => _tahap = v ?? _tahap),
              ),
            )
          else if (p.tahap == PartTahap.dipesan)
            OutlinedButton.icon(
              onPressed: _tahap == PartTahap.dipasang
                  ? null
                  : () => setState(() => _tahap = PartTahap.dipasang),
              icon: Icon(
                _tahap == PartTahap.dipasang
                    ? Icons.check_circle
                    : Icons.build_outlined,
                size: 18,
              ),
              label: Text(
                _tahap == PartTahap.dipasang
                    ? 'DITANDAI SUDAH DIPASANG'
                    : 'PART SUDAH DIPASANG',
              ),
            ),
          const SizedBox(height: AppSpacing.s),

          LabeledField(
            label: 'Catatan',
            child: TextField(
              controller: _catatan,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          const SizedBox(height: AppSpacing.s),

          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: const BoxDecoration(
              color: Color(0x0D0033A0),
              border: Border(left: BorderSide(color: AppColors.blue, width: 3)),
            ),
            child: const Text(
              'Harga, DP, dan pelunasan diatur dari meja depan.',
              style: TextStyle(fontSize: 11, height: 1.4, color: AppColors.blue),
            ),
          ),

          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            onPressed: _busy ? null : _simpan,
            child: Text(_busy ? 'MENYIMPAN…' : 'SIMPAN'),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
      ),
    );
  }
}
