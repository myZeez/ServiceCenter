import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/data/galat.dart';
import '../../core/data/models.dart';
import '../../core/kaca/overlay_kaca.dart';
import '../../core/providers.dart';
import '../../core/status.dart';
import '../../core/theme.dart';
import '../../core/widgets/bento.dart';
import '../../core/widgets/swiss_widgets.dart';

final _tanggal = DateFormat('dd/MM/yyyy');
final _tanggalJam = DateFormat('dd/MM/yyyy HH:mm');

enum _DaftarKembali { menunggu, selesai }

/// Klaim brand yang sudah close, dipisahkan menurut status pengembaliannya.
///
/// Logika ini berdiri di luar widget supaya aturan pentingnya bisa diuji:
/// garansi toko dan status selain close tidak boleh terselip ke meja logistik.
List<Claim> saringPartKembali(
  Iterable<Claim> semua, {
  required bool sudahKembali,
  int? brandId,
  String query = '',
}) {
  final q = query.trim().toLowerCase();
  final hasil = <Claim>[
    for (final c in semua)
      if (c.jenis == 'brand' &&
          c.status == ClaimStatus.close &&
          (c.tanggalPartKembali != null) == sudahKembali &&
          (brandId == null || c.brandId == brandId) &&
          (q.isEmpty ||
              c.namaPelanggan.toLowerCase().contains(q) ||
              (c.telp ?? '').toLowerCase().contains(q) ||
              (c.email ?? '').toLowerCase().contains(q) ||
              c.sn.toLowerCase().contains(q) ||
              (c.noPerbaikan ?? '').toLowerCase().contains(q) ||
              (c.keluhan ?? '').toLowerCase().contains(q)))
        c,
  ];

  hasil.sort((a, b) {
    if (sudahKembali) {
      return b.tanggalPartKembali!.compareTo(a.tanggalPartKembali!);
    }
    return (a.tanggalClose ?? a.tanggal).compareTo(b.tanggalClose ?? b.tanggal);
  });
  return hasil;
}

/// Isi halaman Part Kembali. Dipakai langsung oleh shell Windows dan
/// dibungkus [PartKembaliPage] pada Android.
class PartKembaliView extends ConsumerStatefulWidget {
  const PartKembaliView({super.key, this.showHeader = true});

  final bool showHeader;

  @override
  ConsumerState<PartKembaliView> createState() => _PartKembaliViewState();
}

class _PartKembaliViewState extends ConsumerState<PartKembaliView> {
  final _search = TextEditingController();
  final _sedangDisimpan = <String>{};
  _DaftarKembali _daftar = _DaftarKembali.menunggu;
  int? _brandId;
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _kembalikan(Claim klaim, String brand) async {
    final setuju = await tampilkanDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kembalikan ke brand?'),
        content: Text(
          '${klaim.namaPelanggan}\n'
          'RMA ${_isi(klaim.noPerbaikan)} · $brand\n\n'
          'Klaim akan dipindahkan ke daftar Sudah Kembali.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('BATAL'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('KEMBALIKAN'),
          ),
        ],
      ),
    );
    if (setuju != true || !mounted) return;

    setState(() => _sedangDisimpan.add(klaim.id));
    try {
      await ref.read(databaseProvider).ubahClaim(klaim.id, {
        'tanggal_part_kembali': DateTime.now().toUtc().toIso8601String(),
      });
      ref.invalidate(allClaimsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'RMA ${_isi(klaim.noPerbaikan)} sudah dipindahkan ke '
            'Sudah Kembali.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(pesanGalat(e)),
          duration: const Duration(seconds: 8),
        ),
      );
    } finally {
      if (mounted) setState(() => _sedangDisimpan.remove(klaim.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final claimsAsync = ref.watch(allClaimsProvider);
    final hanyaBaca = ref.watch(isAdminScProvider);
    final brands = ref.watch(allBrandsProvider).valueOrNull ?? const <Brand>[];
    final parts =
        ref.watch(allPartsProvider).valueOrNull ?? const <ClaimPart>[];
    final partTypes =
        ref.watch(allPartTypesProvider).valueOrNull ?? const <PartType>[];
    final profiles =
        ref.watch(allProfilesProvider).valueOrNull ?? const <Profile>[];
    final brandNama = {for (final b in brands) b.id: b.nama};
    final partNama = {for (final p in partTypes) p.id: p.nama};
    final teknisiNama = {for (final p in profiles) p.id: p.nama};
    final partPerKlaim = <String, List<ClaimPart>>{};
    for (final p in parts) {
      partPerKlaim.putIfAbsent(p.claimId, () => []).add(p);
    }

    return claimsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => Center(child: Text(pesanGalat(e))),
      data: (semua) {
        final eligible = [
          for (final c in semua)
            if (c.jenis == 'brand' && c.status == ClaimStatus.close) c,
        ];
        final menunggu = eligible
            .where((c) => c.tanggalPartKembali == null)
            .length;
        final selesai = eligible.length - menunggu;
        final tampil = saringPartKembali(
          eligible,
          sudahKembali: _daftar == _DaftarKembali.selesai,
          brandId: _brandId,
          query: _query,
        );

        final brandTersedia = <int>{for (final c in eligible) c.brandId};
        final pilihanBrand = [
          for (final b in brands)
            if (brandTersedia.contains(b.id)) b,
        ]..sort((a, b) => a.nama.compareTo(b.nama));

        final perBrand = <int, List<Claim>>{};
        for (final c in tampil) {
          perBrand.putIfAbsent(c.brandId, () => []).add(c);
        }
        final brandUrut = perBrand.keys.toList()
          ..sort(
            (a, b) => (brandNama[a] ?? 'Brand $a').compareTo(
              brandNama[b] ?? 'Brand $b',
            ),
          );

        return LayoutBuilder(
          builder: (context, batas) {
            final wide = batas.maxWidth >= 760;
            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s,
                vertical: AppSpacing.xs,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.showHeader) ...[
                    PageHeader(
                      title: 'Part Kembali',
                      subtitle:
                          '$menunggu menunggu dikembalikan · $selesai sudah '
                          'kembali ke brand',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  _TabKembali(
                    daftar: _daftar,
                    menunggu: menunggu,
                    selesai: selesai,
                    onChanged: (v) => setState(() => _daftar = v),
                  ),
                  const SizedBox(height: AppSpacing.s),
                  if (wide)
                    Row(
                      children: [
                        Expanded(child: _pencarian()),
                        const SizedBox(width: AppSpacing.s),
                        _pilihBrand(pilihanBrand),
                      ],
                    )
                  else ...[
                    _pencarian(),
                    const SizedBox(height: AppSpacing.xs),
                    _pilihBrand(pilihanBrand, penuh: true),
                  ],
                  const SizedBox(height: AppSpacing.s),
                  Expanded(
                    child: tampil.isEmpty
                        ? EmptyState(
                            icon: _daftar == _DaftarKembali.menunggu
                                ? Icons.inventory_2_outlined
                                : Icons.task_alt,
                            title: _query.isNotEmpty || _brandId != null
                                ? 'Tidak ada data yang cocok'
                                : _daftar == _DaftarKembali.menunggu
                                ? 'Tidak ada part yang menunggu'
                                : 'Belum ada yang dikembalikan',
                            description: _daftar == _DaftarKembali.menunggu
                                ? 'Hanya klaim brand berstatus Close yang '
                                      'muncul di sini.'
                                : 'Unit akan masuk ke sini setelah tombol '
                                      'Kembalikan ditekan.',
                          )
                        : ListView.builder(
                            key: ValueKey(_daftar),
                            itemCount: brandUrut.length,
                            itemBuilder: (context, index) {
                              final id = brandUrut[index];
                              final items = perBrand[id]!;
                              final nama = brandNama[id] ?? 'Brand $id';
                              return _KelompokBrand(
                                brand: nama,
                                items: items,
                                partPerKlaim: partPerKlaim,
                                partNama: partNama,
                                teknisiNama: teknisiNama,
                                sedangDisimpan: _sedangDisimpan,
                                onKembalikan: hanyaBaca
                                    ? null
                                    : (c) => _kembalikan(c, nama),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _pencarian() => TextField(
    controller: _search,
    decoration: InputDecoration(
      hintText: 'Cari nama, telepon, RMA, SN, email',
      prefixIcon: const Icon(Icons.search, size: 18),
      suffixIcon: _query.isEmpty
          ? null
          : IconButton(
              tooltip: 'Hapus pencarian',
              icon: const Icon(Icons.close, size: 17),
              onPressed: () {
                _search.clear();
                setState(() => _query = '');
              },
            ),
    ),
    onChanged: (v) => setState(() => _query = v),
  );

  Widget _pilihBrand(List<Brand> brands, {bool penuh = false}) => SizedBox(
    width: penuh ? double.infinity : 220,
    child: DropdownButtonFormField<int?>(
      initialValue: _brandId,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Brand'),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('Semua Brand')),
        for (final b in brands)
          DropdownMenuItem<int?>(value: b.id, child: Text(b.nama)),
      ],
      onChanged: (v) => setState(() => _brandId = v),
    ),
  );
}

class _TabKembali extends StatelessWidget {
  const _TabKembali({
    required this.daftar,
    required this.menunggu,
    required this.selesai,
    required this.onChanged,
  });

  final _DaftarKembali daftar;
  final int menunggu;
  final int selesai;
  final ValueChanged<_DaftarKembali> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _TabButton(
          label: 'BELUM KEMBALI',
          count: menunggu,
          selected: daftar == _DaftarKembali.menunggu,
          onTap: () => onChanged(_DaftarKembali.menunggu),
        ),
      ),
      const SizedBox(width: AppSpacing.xs),
      Expanded(
        child: _TabButton(
          label: 'SUDAH KEMBALI',
          count: selesai,
          selected: daftar == _DaftarKembali.selesai,
          onTap: () => onChanged(_DaftarKembali.selesai),
        ),
      ),
    ],
  );
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(AppRadius.small),
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s,
        vertical: AppSpacing.s,
      ),
      decoration: BoxDecoration(
        color: selected ? context.warna.teks : Colors.transparent,
        border: Border.all(color: context.warna.teks),
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: .6,
                color: selected ? context.warna.diTeks : context.warna.teks,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '$count',
            style: gayaAngka(context, ukuran: 13, tebal: FontWeight.w700)
                .copyWith(
                  color: selected ? context.warna.diTeks : context.warna.teks,
                ),
          ),
        ],
      ),
    ),
  );
}

class _KelompokBrand extends StatelessWidget {
  const _KelompokBrand({
    required this.brand,
    required this.items,
    required this.partPerKlaim,
    required this.partNama,
    required this.teknisiNama,
    required this.sedangDisimpan,
    required this.onKembalikan,
  });

  final String brand;
  final List<Claim> items;
  final Map<String, List<ClaimPart>> partPerKlaim;
  final Map<int, String> partNama;
  final Map<String, String> teknisiNama;
  final Set<String> sedangDisimpan;
  final ValueChanged<Claim>? onKembalikan;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel('$brand · ${items.length}'),
        const SizedBox(height: AppSpacing.xs),
        for (var i = 0; i < items.length; i++) ...[
          _KartuKembali(
            klaim: items[i],
            parts: partPerKlaim[items[i].id] ?? const [],
            partNama: partNama,
            teknisiNama: teknisiNama,
            busy: sedangDisimpan.contains(items[i].id),
            onKembalikan: onKembalikan == null
                ? null
                : () => onKembalikan!(items[i]),
          ),
          if (i != items.length - 1) const SizedBox(height: AppSpacing.xs),
        ],
      ],
    ),
  );
}

class _KartuKembali extends StatelessWidget {
  const _KartuKembali({
    required this.klaim,
    required this.parts,
    required this.partNama,
    required this.teknisiNama,
    required this.busy,
    required this.onKembalikan,
  });

  final Claim klaim;
  final List<ClaimPart> parts;
  final Map<int, String> partNama;
  final Map<String, String> teknisiNama;
  final bool busy;
  final VoidCallback? onKembalikan;

  String get _claimPart => parts.isEmpty
      ? ''
      : parts
            .map((p) => partNama[p.partTypeId] ?? 'Part ${p.partTypeId}')
            .join(', ');

  String get _snBadPart => parts
      .map((p) => (p.snBadPart ?? '').trim())
      .where((sn) => sn.isNotEmpty)
      .join(', ');

  @override
  Widget build(BuildContext context) {
    final sudah = klaim.tanggalPartKembali != null;
    // Urutannya mengikuti buku pengembalian part. Slotnya tetap sama agar
    // kartu tidak berubah tinggi hanya karena satu nilai lebih panjang.
    final fields = <(String, String)>[
      ('Tanggal Masuk', _tanggal.format(klaim.tanggal)),
      ('Nama', klaim.namaPelanggan),
      ('Telepon', _isi(klaim.telp)),
      ('SN Unit', _isi(klaim.sn)),
      ('Teknisi', _isi(teknisiNama[klaim.teknisiId])),
      ('Keluhan', _isi(klaim.keluhan)),
      ('RMA / No. Perbaikan', _isi(klaim.noPerbaikan)),
      ('Claim Part', _isi(_claimPart)),
      ('Status', ClaimStatus.label(klaim.status)),
      ('SN Bad Part', _isi(_snBadPart)),
      ('Catatan', _isi(klaim.catatan)),
    ];

    return Container(
      key: ValueKey('part-kembali-${klaim.id}'),
      padding: const EdgeInsets.all(AppSpacing.s),
      decoration: BoxDecoration(
        color: context.warna.permukaan,
        border: Border.all(color: context.warna.garisHalus),
        borderRadius: BorderRadius.circular(AppRadius.base),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 44,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        klaim.namaPelanggan,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'RMA ${_isi(klaim.noPerbaikan)} · '
                        'SN ${_isi(klaim.sn)}',
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: gayaAngka(context, ukuran: 11),
                      ),
                    ],
                  ),
                ),
                if (sudah) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: context.warna.garansi),
                      borderRadius: BorderRadius.circular(AppRadius.small),
                    ),
                    child: Text(
                      _tanggalJam.format(klaim.tanggalPartKembali!),
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        color: context.warna.garansi,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          LayoutBuilder(
            builder: (context, batas) =>
                _GridDataKembali(fields: fields, width: batas.maxWidth),
          ),
          const SizedBox(height: AppSpacing.s),
          if (!sudah && onKembalikan != null)
            SizedBox(
              height: 40,
              child: Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: 190,
                  height: 40,
                  child: FilledButton.icon(
                    key: ValueKey('kembalikan-${klaim.id}'),
                    onPressed: busy ? null : onKembalikan,
                    icon: busy
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.keyboard_return, size: 17),
                    label: Text(busy ? 'MENYIMPAN…' : 'KEMBALIKAN'),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Kolom mengikuti buku pengembalian part, tetapi tidak dipaksa semua duduk
/// dalam satu baris kecil. Setiap kolom memiliki tinggi yang sama dan nilainya
/// selalu satu baris; teks panjang dipotong visual saja, bukan membesarkan kartu.
class _GridDataKembali extends StatelessWidget {
  const _GridDataKembali({required this.fields, required this.width});

  final List<(String, String)> fields;
  final double width;

  @override
  Widget build(BuildContext context) {
    final columns = switch (width) {
      >= 1500 => 6,
      >= 1100 => 4,
      >= 680 => 3,
      >= 360 => 2,
      _ => 1,
    };
    final itemWidth = (width - AppSpacing.xs * (columns - 1)) / columns;
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final (label, value) in fields)
          SizedBox(
            width: itemWidth,
            child: _DataSalin(label: label, value: value),
          ),
      ],
    );
  }
}

class _DataSalin extends StatelessWidget {
  const _DataSalin({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final bisaDisalin = value != '—' && value.trim().isNotEmpty;
    return Tooltip(
      message: bisaDisalin ? value : '$label belum tersedia',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.small),
        onTap: bisaDisalin ? () => _salin(context, label, value) : null,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border.all(color: context.warna.garisHalus),
            borderRadius: BorderRadius.circular(AppRadius.small),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label.toUpperCase(),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (bisaDisalin) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.copy_outlined,
                  size: 15,
                  color: context.warna.teksLembut,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _salin(BuildContext context, String label, String value) async {
  await Clipboard.setData(ClipboardData(text: value));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text('$label disalin')));
}

String _isi(String? value) {
  final v = value?.trim() ?? '';
  return v.isEmpty ? '—' : v;
}
