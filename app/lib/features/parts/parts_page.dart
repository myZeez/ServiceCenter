import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/data/galat.dart';
import '../../core/data/models.dart';
import '../../core/kaca/overlay_kaca.dart';
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
/// Yang bisa diubah teknisi sedikit dan disengaja: kode part, catatan, dan
/// dua penanda -- kode sudah diisi, dan part sudah dipasang. Keduanya hal
/// yang memang ia ketahui lebih dulu daripada meja depan. Harga, DP, dan
/// pelunasan tetap urusan admin: server menolaknya, jadi menampilkan
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
        actions: const [
          IndikatorKoneksi(),
          SizedBox(width: AppSpacing.xs),
        ],
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
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.warna.teks)),
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
                  label: '${PartTahap.pendek(t).toUpperCase()}  ${jumlah[t]}',
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
            color: aktif ? context.warna.teks : context.warna.permukaan,
            border: Border.all(color: context.warna.teks),
            borderRadius: BorderRadius.circular(AppRadius.small),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: aktif ? context.warna.kertas : context.warna.teks,
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
      onTap: () => tampilkanLembar<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: context.warna.permukaan,
        builder: (_) => _UbahPart(pesanan: p),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.s,
        ),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.warna.garisHalus)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _tgl.format(p.tanggal),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
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
                style: TextStyle(
                  fontSize: 12.5,
                  color: context.warna.teksLembut,
                ),
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
  late String _tahap = widget.pesanan.tahap;
  late final _partReq = TextEditingController(text: widget.pesanan.partReq);
  late final _catatan = TextEditingController(
    text: widget.pesanan.catatan ?? '',
  );

  bool _busy = false;

  @override
  void dispose() {
    _partReq.dispose();
    _catatan.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    if (_partReq.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kode part tidak boleh kosong.')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(databaseProvider).ubahPartOrder(widget.pesanan.id, {
        'part_req': _partReq.text.trim(),
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
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Pesanan diperbarui')));
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

          // Inilah yang ditunggu ratusan baris di tahap "Tunggu Kode Part":
          // kode persisnya hanya ada di tangan orang yang membuka unitnya.
          // Kalau teknisi tidak bisa mengetiknya dari sini, tahap itu tidak
          // akan pernah bergerak tanpa bolak-balik ke meja depan.
          LabeledField(
            label: 'Kode / Nama Part',
            hint: 'Sebutkan sedetail yang terbaca di partnya.',
            child: TextField(
              controller: _partReq,
              maxLines: 2,
              textCapitalization: TextCapitalization.characters,
            ),
          ),
          const SizedBox(height: AppSpacing.s),

          // Teknisi hanya mendapat dua perpindahan, dan keduanya hal yang
          // memang ia ketahui lebih dulu daripada meja depan. Dropdown
          // penuh akan menawarkan tahap yang pasti ditolak server, dan
          // penolakan yang bisa diramalkan sebaiknya tidak pernah
          // ditawarkan.
          if (isAdmin)
            LabeledField(
              label: 'Tahap',
              child: DropdownButtonFormField<String>(
                initialValue: _tahap,
                isExpanded: true,
                items: [
                  for (final t in PartTahap.all)
                    DropdownMenuItem(
                      value: t,
                      child: Text(PartTahap.label(t)),
                    ),
                ],
                onChanged: (v) => setState(() => _tahap = v ?? _tahap),
              ),
            )
          else if (p.tahap == PartTahap.foto)
            _TombolTahap(
              aktif: _tahap == PartTahap.harga,
              label: 'KODE PART SUDAH DIISI',
              labelAktif: 'DITERUSKAN KE MEJA DEPAN',
              ikon: Icons.send_outlined,
              onTekan: () => setState(() => _tahap = PartTahap.harga),
            )
          else if (p.tahap == PartTahap.dipesan)
            _TombolTahap(
              aktif: _tahap == PartTahap.dipasang,
              label: 'PART SUDAH DIPASANG',
              labelAktif: 'DITANDAI SUDAH DIPASANG',
              ikon: Icons.build_outlined,
              onTekan: () => setState(() => _tahap = PartTahap.dipasang),
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
            decoration: BoxDecoration(
              color: context.warna.aksen.withValues(alpha: 0.05),
              border: Border(
                left: BorderSide(color: context.warna.aksen, width: 3),
              ),
            ),
            child: Text(
              'Harga, DP, dan pelunasan diatur dari meja depan.',
              style: TextStyle(
                fontSize: 11,
                height: 1.4,
                color: context.warna.aksen,
              ),
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

/// Tombol yang menandai satu perpindahan tahap, dan berubah bunyi begitu
/// ditekan.
///
/// Perubahannya baru tersimpan saat SIMPAN ditekan, jadi tombolnya harus
/// menyatakan "sudah ditandai", bukan "sudah terjadi" -- kalimat yang
/// mengklaim lebih dari yang benar akan membuat orang menutup lembarnya
/// tanpa menyimpan.
class _TombolTahap extends StatelessWidget {
  const _TombolTahap({
    required this.aktif,
    required this.label,
    required this.labelAktif,
    required this.ikon,
    required this.onTekan,
  });

  final bool aktif;
  final String label;
  final String labelAktif;
  final IconData ikon;
  final VoidCallback onTekan;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: aktif ? null : onTekan,
    icon: Icon(aktif ? Icons.check_circle : ikon, size: 18),
    label: Text(aktif ? labelAktif : label),
  );
}
