import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/data/galat.dart';
import '../../core/data/models.dart';
import '../../core/providers.dart';
import '../../core/revenue/revenue_calculator.dart';
import '../../core/revenue/revenue_providers.dart';
import '../../core/status.dart';
import '../../core/theme.dart';
import '../../core/widgets/bento.dart';
import '../../core/widgets/swiss_widgets.dart';

final _rp = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp',
  decimalDigits: 0,
);
final _bulanFmt = DateFormat('MMMM yyyy', 'id');
final _tglFmt = DateFormat('dd/MM/yy');
final _tglPanjang = DateFormat('d MMMM yyyy', 'id');
final _iso = DateFormat('yyyy-MM-dd');

DateTime _awalBulan(DateTime d) => DateTime(d.year, d.month);

// =====================================================================
// Keadaan halaman
// =====================================================================

/// Bulan rekap yang sedang dibuka. Bawaannya bulan berjalan -- itulah surat
/// yang biasanya sedang ada di meja.
final bulanRekapProvider = StateProvider<DateTime>(
  (ref) => _awalBulan(DateTime.now()),
);

/// null berarti semua brand. Surat datang per brand, jadi penyaringan ini
/// yang paling sering dipakai.
final brandRekapProvider = StateProvider<int?>((ref) => null);

/// Menyembunyikan unit yang sudah dicocokkan, supaya yang tersisa di layar
/// hanya yang masih perlu dikerjakan.
final hanyaBelumProvider = StateProvider<bool>((ref) => false);

/// Bulan yang benar-benar punya unit selesai, terbaru di atas. Bulan
/// berjalan selalu ikut walau masih kosong -- di situlah unit hari ini akan
/// jatuh, dan daftar yang tidak memuatnya terasa seperti kerusakan.
final _bulanTersediaProvider = Provider.autoDispose<List<DateTime>>((ref) {
  final claims = ref.watch(allClaimsProvider).valueOrNull ?? const <Claim>[];

  final bulan = <DateTime>{_awalBulan(DateTime.now())};
  for (final c in claims) {
    if (!ClaimStatus.isTuntas(c.status)) continue;
    final t = c.tanggalClose;
    if (t != null) bulan.add(_awalBulan(t));
  }

  return bulan.toList()..sort((a, b) => b.compareTo(a));
});

/// Satu unit yang siap dicocokkan dengan surat brand.
class UnitRekap {
  const UnitRekap({
    required this.klaim,
    required this.brand,
    required this.teknisi,
    required this.nilaiAwal,
    required this.hasil,
  });

  final Claim klaim;
  final String brand;
  final String? teknisi;

  /// Fee brand yang berlaku pada tanggal klaim. Dipakai selama surat brand
  /// belum menyebut angka lain untuk unit ini.
  final double nilaiAwal;

  final ClaimSettlement? hasil;

  double get nilai => hasil?.fee ?? nilaiAwal;

  /// Angkanya sudah diambil dari surat brand, bukan lagi dari pengaturan.
  bool get dikoreksi => hasil?.fee != null;

  bool get cocok => hasil?.cocok ?? false;

  String? get catatan => hasil?.catatan;
}

/// Unit selesai pada bulan terpilih, sudah disaring menurut brand.
///
/// null berarti datanya belum sampai -- berbeda dari daftar kosong, yang
/// berarti bulan itu memang tidak ada unit selesai.
final unitRekapProvider = Provider.autoDispose<List<UnitRekap>?>((ref) {
  final claims = ref.watch(allClaimsProvider).valueOrNull;
  final fees = ref.watch(brandFeesProvider).valueOrNull;
  if (claims == null || fees == null) return null;

  final brands = {
    for (final b in ref.watch(allBrandsProvider).valueOrNull ?? const <Brand>[])
      b.id: b.nama,
  };
  final teknisi = {
    for (final p
        in ref.watch(allProfilesProvider).valueOrNull ?? const <Profile>[])
      p.id: p.nama,
  };
  final hasil = ref.watch(settlementByClaimProvider);

  final bulan = ref.watch(bulanRekapProvider);
  final brandId = ref.watch(brandRekapProvider);

  final daftarFee = [
    for (final f in fees)
      BrandFee(brandId: f.brandId, fee: f.fee, berlakuDari: f.berlakuDari),
  ];

  final out = <UnitRekap>[];
  for (final c in claims) {
    if (!ClaimStatus.isTuntas(c.status)) continue;
    // Garansi toko tidak pernah ditagihkan: unitnya ditanggung toko
    // sendiri, dan tidak ada fee brand yang bisa direkap. Memasukkannya
    // ke sini berarti menagih brand atas pekerjaan yang tidak pernah
    // mereka setujui.
    if (!ClaimJenis.ditagihkan(c.jenis)) continue;
    if (brandId != null && c.brandId != brandId) continue;

    final tutup = c.tanggalClose;
    if (tutup == null || _awalBulan(tutup) != bulan) continue;

    out.add(
      UnitRekap(
        klaim: c,
        brand: brands[c.brandId] ?? '—',
        teknisi: teknisi[c.teknisiId],
        nilaiAwal: feeUntuk(daftarFee, c.brandId, c.tanggal),
        hasil: hasil[c.id],
      ),
    );
  }

  // Urutannya mengikuti cara surat brand dibaca: per brand, lalu menurut
  // nomor perbaikan. Unit yang nomornya belum diisi dikumpulkan di bawah --
  // itu justru yang perlu dibereskan lebih dulu, dan menyelipkannya di
  // tengah daftar membuatnya luput.
  out.sort((a, b) {
    final brand = a.brand.compareTo(b.brand);
    if (brand != 0) return brand;

    final ra = a.klaim.noPerbaikan ?? '';
    final rb = b.klaim.noPerbaikan ?? '';
    if (ra.isEmpty != rb.isEmpty) return ra.isEmpty ? 1 : -1;
    if (ra != rb) return ra.compareTo(rb);

    return a.klaim.tanggal.compareTo(b.klaim.tanggal);
  });

  return out;
});

// =====================================================================
// Halaman
// =====================================================================

/// Pencocokan rekap bulanan dari brand.
///
/// Tiap bulan brand mengirim daftar unit yang sudah tuntas beserta biaya
/// yang mereka bayar, dan angkanya berbeda-beda per unit. Halaman ini
/// menyandingkan daftar itu dengan catatan sendiri, memakai nomor perbaikan
/// sebagai penghubung.
class SettlementView extends ConsumerWidget {
  const SettlementView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bulan = ref.watch(bulanRekapProvider);
    final units = ref.watch(unitRekapProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s,
        vertical: AppSpacing.xs,
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth > 900;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'Rekap Brand',
                subtitle:
                    '${_bulanFmt.format(bulan)}  ·  unit yang klaimnya sudah '
                    'Selesai, untuk dicocokkan dengan surat brand',
                actions: wide
                    ? const [
                        _BrandDropdown(),
                        SizedBox(width: AppSpacing.xs),
                        _BulanDropdown(),
                      ]
                    : const [],
              ),
              if (!wide) ...[
                const SizedBox(height: AppSpacing.s),
                const Row(
                  children: [
                    Expanded(child: _BrandDropdown()),
                    SizedBox(width: AppSpacing.xs),
                    Expanded(child: _BulanDropdown()),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.s),
              if (units != null) ...[
                _Ringkasan(units),
                const SizedBox(height: AppSpacing.s),
              ],
              Expanded(
                child: units == null
                    ? const Center(
                        child: SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _Daftar(units, wide: wide),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Ringkasan extends ConsumerWidget {
  const _Ringkasan(this.units);

  final List<UnitRekap> units;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cocok = units.where((u) => u.cocok).length;
    final belum = units.length - cocok;
    final nilai = units.fold<double>(0, (a, u) => a + u.nilai);
    final hanyaBelum = ref.watch(hanyaBelumProvider);

    return Row(
      children: [
        Expanded(
          child: StatTile(value: '${units.length}', label: 'Unit Selesai'),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: StatTile(value: '$cocok', label: 'Sudah Cocok'),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: StatTile(
            value: '$belum',
            label: 'Belum Cocok',
            accent: context.warna.bahaya,
            selected: hanyaBelum,
            // Ringkasan sekaligus kendali: menyentuhnya menyisakan yang
            // masih harus dikerjakan saja.
            onTap: () =>
                ref.read(hanyaBelumProvider.notifier).state = !hanyaBelum,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(flex: 2, child: _NilaiTile(nilai)),
      ],
    );
  }
}

/// Angka yang dibandingkan dengan total di surat brand. Sengaja memakai
/// FittedBox: rupiah tujuh angka tidak muat pada ukuran yang sama dengan
/// jumlah unit, dan yang terpotong di tepi tidak bisa dicocokkan.
class _NilaiTile extends StatelessWidget {
  const _NilaiTile(this.nilai);

  final double nilai;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s),
      decoration: BoxDecoration(
        color: context.warna.permukaan,
        borderRadius: BorderRadius.circular(AppRadius.base),
        border: Border.all(color: context.warna.garisHalus),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _rp.format(nilai),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -1,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'NILAI TOTAL BULAN INI',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _Daftar extends ConsumerWidget {
  const _Daftar(this.units, {required this.wide});

  final List<UnitRekap> units;
  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hanyaBelum = ref.watch(hanyaBelumProvider);
    final tampil = hanyaBelum ? units.where((u) => !u.cocok).toList() : units;

    if (units.isEmpty) {
      return const BentoCard(
        padding: EdgeInsets.zero,
        child: EmptyState(
          icon: Icons.event_busy_outlined,
          title: 'Belum ada unit selesai di bulan ini',
          description:
              'Unit muncul di sini begitu klaimnya ditandai Selesai. '
              'Bulannya mengikuti tanggal klaim itu ditutup, bukan tanggal '
              'unitnya datang.',
        ),
      );
    }

    if (tampil.isEmpty) {
      return BentoCard(
        padding: EdgeInsets.zero,
        child: EmptyState(
          icon: Icons.done_all,
          title: 'Semua unit bulan ini sudah cocok',
          description:
              '${units.length} unit sudah dicocokkan dengan surat brand.',
          action: OutlinedButton(
            onPressed: () =>
                ref.read(hanyaBelumProvider.notifier).state = false,
            child: const Text('TAMPILKAN SEMUA'),
          ),
        ),
      );
    }

    return BentoCard(
      title: 'Unit Selesai',
      padding: EdgeInsets.zero,
      trailing: hanyaBelum
          ? InlineAction(
              label: 'Tampilkan semua',
              onTap: () => ref.read(hanyaBelumProvider.notifier).state = false,
            )
          : null,
      child: wide ? _Tabel(tampil) : _Kartu(tampil),
    );
  }
}

// =====================================================================
// Tabel untuk layar lebar
// =====================================================================

class _Tabel extends StatelessWidget {
  const _Tabel(this.units);

  final List<UnitRekap> units;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        // Kolom yang paling sedikit dipakai menghilang lebih dulu saat
        // bidangnya menyempit; nomor perbaikan dan nilai tidak pernah,
        // karena keduanya inti pekerjaan di halaman ini.
        final w = c.maxWidth;
        final adaBrand = w >= 980;
        final adaSn = w >= 820;
        final adaTeknisi = w >= 1160;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: context.warna.teks, width: 1.5),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.s,
                AppSpacing.sm,
                AppSpacing.xs,
              ),
              child: Row(
                children: [
                  const _Kepala('No Perbaikan', width: 132),
                  if (adaBrand) const _Kepala('Brand', width: 84),
                  const _Kepala('Pelanggan', flex: 3),
                  if (adaSn) const _Kepala('SN', width: 140),
                  if (adaTeknisi) const _Kepala('Teknisi', width: 100),
                  const _Kepala('Tutup', width: 70),
                  const _Kepala('Nilai', width: 122, kanan: true),
                  const _Kepala('Cocok', width: 56, kanan: true),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: AppSpacing.s),
                itemCount: units.length,
                itemBuilder: (context, i) => _Baris(
                  units[i],
                  adaBrand: adaBrand,
                  adaSn: adaSn,
                  adaTeknisi: adaTeknisi,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Kepala extends StatelessWidget {
  const _Kepala(this.label, {this.width, this.flex, this.kanan = false});

  final String label;
  final double? width;
  final int? flex;
  final bool kanan;

  @override
  Widget build(BuildContext context) {
    final teks = Padding(
      padding: const EdgeInsets.only(right: AppSpacing.s),
      child: Text(
        label.toUpperCase(),
        textAlign: kanan ? TextAlign.right : TextAlign.left,
        overflow: TextOverflow.clip,
        softWrap: false,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
          color: context.warna.teks,
        ),
      ),
    );

    if (width != null) return SizedBox(width: width, child: teks);
    return Expanded(flex: flex ?? 1, child: teks);
  }
}

class _Baris extends StatelessWidget {
  const _Baris(
    this.unit, {
    required this.adaBrand,
    required this.adaSn,
    required this.adaTeknisi,
  });

  final UnitRekap unit;
  final bool adaBrand;
  final bool adaSn;
  final bool adaTeknisi;

  @override
  Widget build(BuildContext context) {
    final c = unit.klaim;
    final rma = c.noPerbaikan ?? '';

    Widget sel(Widget child, {double? width, int? flex}) {
      final isi = Padding(
        padding: const EdgeInsets.only(right: AppSpacing.s),
        child: child,
      );
      if (width != null) return SizedBox(width: width, child: isi);
      return Expanded(flex: flex ?? 1, child: isi);
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.warna.garisHalus)),
      ),
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 8, AppSpacing.sm, 8),
      child: Row(
        children: [
          sel(
            // Tanpa nomor perbaikan, unit ini tidak bisa dicari di surat
            // brand sama sekali. Ditandai merah, bukan diberi tanda hubung
            // seperti kolom kosong biasa.
            rma.isEmpty
                ? Text(
                    'BELUM ADA RMA',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: context.warna.bahaya,
                    ),
                  )
                : Text(
                    rma,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
            width: 132,
          ),
          if (adaBrand)
            sel(
              Text(
                unit.brand.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              width: 84,
            ),
          sel(
            Text(
              c.namaPelanggan,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
            flex: 3,
          ),
          if (adaSn)
            sel(
              Text(
                c.sn,
                style: const TextStyle(fontSize: 13, letterSpacing: 0.2),
                overflow: TextOverflow.ellipsis,
              ),
              width: 140,
            ),
          if (adaTeknisi)
            sel(
              Text(
                unit.teknisi ?? '—',
                style: TextStyle(
                  fontSize: 13,
                  color: unit.teknisi == null
                      ? context.warna.teksLembut
                      : context.warna.teks,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              width: 100,
            ),
          sel(
            Text(
              c.tanggalClose == null ? '—' : _tglFmt.format(c.tanggalClose!),
              style: TextStyle(fontSize: 13, color: context.warna.teksLembut),
            ),
            width: 70,
          ),
          sel(_NilaiSel(unit), width: 122),
          SizedBox(
            width: 56,
            child: Align(
              alignment: Alignment.centerRight,
              child: _CocokBox(unit),
            ),
          ),
        ],
      ),
    );
  }
}

/// Nilai satu unit, sekaligus tombol untuk mengoreksinya.
///
/// Angka yang masih memakai fee brand ditulis abu-abu; yang sudah diambil
/// dari surat brand ditulis hitam. Perbedaan itu yang membuat sisa
/// pekerjaan terlihat tanpa membaca kolom lain.
class _NilaiSel extends ConsumerWidget {
  const _NilaiSel(this.unit);

  final UnitRekap unit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => ubahNilai(context, ref, unit),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _rp.format(unit.nilai),
              style: TextStyle(
                fontSize: 13,
                fontWeight: unit.dikoreksi ? FontWeight.w700 : FontWeight.w400,
                color: unit.dikoreksi ? context.warna.teks : context.warna.teksLembut,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            if (!unit.dikoreksi)
              Text('NILAI AWAL', style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _CocokBox extends ConsumerWidget {
  const _CocokBox(this.unit);

  final UnitRekap unit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Checkbox(
      value: unit.cocok,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onChanged: (v) => setCocok(context, ref, unit, v ?? false),
    );
  }
}

// =====================================================================
// Kartu untuk layar sempit
// =====================================================================

class _Kartu extends StatelessWidget {
  const _Kartu(this.units);

  final List<UnitRekap> units;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      itemCount: units.length,
      separatorBuilder: (_, _) => const Divider(),
      itemBuilder: (context, i) => _KartuBaris(units[i]),
    );
  }
}

class _KartuBaris extends StatelessWidget {
  const _KartuBaris(this.unit);

  final UnitRekap unit;

  @override
  Widget build(BuildContext context) {
    final c = unit.klaim;
    final rma = c.noPerbaikan ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      unit.brand.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        rma.isEmpty ? 'BELUM ADA RMA' : rma,
                        style: TextStyle(
                          fontSize: rma.isEmpty ? 9.5 : 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: rma.isEmpty ? 0.8 : 0.3,
                          color: rma.isEmpty ? context.warna.bahaya : context.warna.teks,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  c.namaPelanggan,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${c.sn}  ·  tutup '
                  '${c.tanggalClose == null ? '—' : _tglFmt.format(c.tanggalClose!)}',
                  style: Theme.of(context).textTheme.labelSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          SizedBox(width: 116, child: _NilaiSel(unit)),
          _CocokBox(unit),
        ],
      ),
    );
  }
}

// =====================================================================
// Penyaring
// =====================================================================

class _BrandDropdown extends ConsumerWidget {
  const _BrandDropdown();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brands = ref.watch(allBrandsProvider).valueOrNull ?? const <Brand>[];

    return _Dropdown<int?>(
      value: ref.watch(brandRekapProvider),
      placeholder: 'SEMUA BRAND',
      items: [for (final b in brands) (b.id, b.nama.toUpperCase())],
      onChanged: (v) => ref.read(brandRekapProvider.notifier).state = v,
    );
  }
}

class _BulanDropdown extends ConsumerWidget {
  const _BulanDropdown();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tersedia = ref.watch(_bulanTersediaProvider);
    final terpilih = ref.watch(bulanRekapProvider);

    // Bulan yang sedang dipilih bisa hilang dari daftar setelah klaim
    // terakhirnya dibuka kembali. Dropdown dengan nilai yang tidak ada di
    // antara pilihannya melempar galat, jadi nilainya selalu diikutkan.
    final daftar = tersedia.contains(terpilih)
        ? tersedia
        : ([...tersedia, terpilih]..sort((a, b) => b.compareTo(a)));

    return _Dropdown<DateTime>(
      value: terpilih,
      items: [for (final b in daftar) (b, _bulanFmt.format(b).toUpperCase())],
      onChanged: (v) => ref.read(bulanRekapProvider.notifier).state = v!,
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    required this.value,
    required this.items,
    required this.onChanged,
    this.placeholder,
  });

  final T value;
  final String? placeholder;
  final List<(T, String)> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      // Lebar tetap, bukan sekadar batas bawah. Di kepala halaman kotak ini
      // berdiri tanpa lebar dari induknya, dan DropdownButton yang memuai
      // di ruang tak terbatas melempar galat tata letak.
      width: 168,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      decoration: BoxDecoration(
        border: Border.all(
          color: value == null ? context.warna.garisIsian : context.warna.teks,
        ),
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          isExpanded: true,
          borderRadius: BorderRadius.circular(AppRadius.base),
          // Tanpa ini, Flutter melukis blok abu di belakang teks saat
          // dropdown mendapat fokus -- terlihat seperti kerusakan tampilan.
          focusColor: Colors.transparent,
          icon: const Icon(Icons.expand_more, size: 16),
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
            color: context.warna.teks,
          ),
          onChanged: onChanged,
          items: [
            if (placeholder != null)
              DropdownMenuItem<T>(value: null, child: Text(placeholder!)),
            for (final (v, label) in items)
              DropdownMenuItem<T>(value: v, child: Text(label)),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// Penyimpanan
// =====================================================================

/// Mengisi nilai sekaligus menandai unitnya cocok: angka itu tidak datang
/// dari mana-mana selain surat brand, jadi mengetiknya sudah merupakan
/// pernyataan bahwa unitnya ada di surat itu.
Future<void> ubahNilai(
  BuildContext context,
  WidgetRef ref,
  UnitRekap unit,
) async {
  final hasil =
      await showDialog<({double? fee, String? catatan, DateTime tutup})>(
        context: context,
        builder: (_) => _NilaiDialog(unit),
      );
  if (hasil == null || !context.mounted) return;

  final db = ref.read(databaseProvider);

  await _jalankan(context, () async {
    await db.simpanSettlement({
      'claim_id': unit.klaim.id,
      'fee': hasil.fee,
      'cocok': true,
      'catatan': hasil.catatan,
    });

    // Brand kadang memasukkan sebuah unit ke bulan yang berbeda dari
    // catatan sendiri -- dan tanggal tutup klaim lama hanya perkiraan dari
    // waktu perubahan terakhirnya. Memindahkannya harus bisa dilakukan dari
    // sini, karena di sini selisihnya ketahuan.
    if (hasil.tutup != unit.klaim.tanggalClose) {
      await db.ubahClaim(unit.klaim.id, {
        'tanggal_close': _iso.format(hasil.tutup),
      });
    }
  });
}

Future<void> setCocok(
  BuildContext context,
  WidgetRef ref,
  UnitRekap unit,
  bool cocok,
) async {
  final db = ref.read(databaseProvider);
  final ada = unit.hasil;

  // Melepas centang pada unit yang belum pernah dicatat tidak mengubah apa
  // pun; menuliskannya justru meninggalkan baris kosong.
  if (!cocok && ada == null) return;

  final adaCatatan = (ada?.catatan ?? '').isNotEmpty;
  if (!cocok && ada?.fee == null && !adaCatatan) {
    await _jalankan(context, () => db.hapusSettlement(unit.klaim.id));
    return;
  }

  await _jalankan(
    context,
    () => db.simpanSettlement({
      'claim_id': unit.klaim.id,
      'fee': ada?.fee,
      'cocok': cocok,
      'catatan': ada?.catatan,
    }),
  );
}

Future<void> _jalankan(
  BuildContext context,
  Future<void> Function() aksi,
) async {
  try {
    await aksi();
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(pesanGalat(e))));
  }
}

class _NilaiDialog extends StatefulWidget {
  const _NilaiDialog(this.unit);

  final UnitRekap unit;

  @override
  State<_NilaiDialog> createState() => _NilaiDialogState();
}

class _NilaiDialogState extends State<_NilaiDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _fee = TextEditingController(text: '${widget.unit.nilai.round()}');
  late final _catatan = TextEditingController(text: widget.unit.catatan ?? '');

  /// Klaim yang statusnya sudah selesai selalu punya tanggal ini; bawaan
  /// hari ini hanya untuk baris yang entah bagaimana lolos tanpa stempel.
  late DateTime _tutup = widget.unit.klaim.tanggalClose ?? DateTime.now();

  @override
  void dispose() {
    _fee.dispose();
    _catatan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.unit;

    return AlertDialog(
      title: Text(u.klaim.noPerbaikan ?? u.klaim.sn),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${u.brand}  ·  ${u.klaim.namaPelanggan}  ·  ${u.klaim.sn}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: AppSpacing.s),
              LabeledField(
                label: 'Biaya dari Brand',
                required: true,
                hint:
                    'Angka yang tertulis di rekap brand untuk unit ini. '
                    'Nilai awal dari pengaturan: ${_rp.format(u.nilaiAwal)}.',
                child: TextFormField(
                  controller: _fee,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(prefixText: 'Rp '),
                  validator: (v) {
                    // Nol diterima: brand kadang tidak membayar sebuah unit,
                    // dan itu keterangan yang harus bisa dicatat apa adanya.
                    final n = int.tryParse(v ?? '');
                    return n == null ? 'Isi angkanya' : null;
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.s),
              LabeledField(
                label: 'Catatan',
                hint:
                    'Mis. selisih dengan surat, atau alasan brand tidak '
                    'membayar unit ini.',
                child: TextFormField(controller: _catatan, maxLines: 2),
              ),
              const SizedBox(height: AppSpacing.s),
              LabeledField(
                label: 'Masuk Rekap Bulan',
                hint:
                    'Menentukan unit ini muncul di bulan mana. Ubah kalau '
                    'brand memasukkannya ke surat bulan lain.',
                child: OutlinedButton(
                  onPressed: () async {
                    final pilih = await showDatePicker(
                      context: context,
                      initialDate: _tutup,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
                    );
                    if (pilih != null) setState(() => _tutup = pilih);
                  },
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    side: BorderSide(color: context.warna.garisIsian),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s,
                      vertical: 13,
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _tglPanjang.format(_tutup),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('BATAL'),
        ),
        if (u.dikoreksi)
          TextButton(
            // Mengembalikan unit ke nilai awal, bukan melepas centangnya:
            // yang keliru adalah angkanya, bukan kenyataan bahwa unit itu
            // ada di surat brand.
            onPressed: () => Navigator.pop(context, (
              fee: null,
              catatan: _isiCatatan(),
              tutup: _tutup,
            )),
            child: const Text('PAKAI NILAI AWAL'),
          ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(context, (
              fee: double.parse(_fee.text),
              catatan: _isiCatatan(),
              tutup: _tutup,
            ));
          },
          child: const Text('SIMPAN'),
        ),
      ],
    );
  }

  String? _isiCatatan() {
    final t = _catatan.text.trim();
    return t.isEmpty ? null : t;
  }
}
