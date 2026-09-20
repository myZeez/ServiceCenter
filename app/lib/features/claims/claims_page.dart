import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/data/models.dart';
import '../../core/fitur.dart';
import '../../core/providers.dart';
import '../../core/status.dart';
import '../../core/theme.dart';
import '../../core/widgets/gagal_muat.dart';
import '../../core/widgets/koneksi.dart';
import '../../core/widgets/swiss_widgets.dart';
import '../mywork/my_work_page.dart';
import '../parts/parts_page.dart';
import '../service/service_page.dart';
import '../service/servisku_view.dart';
import '../reports/reports_page.dart';
import '../scan/scan_page.dart';
import '../settings/settings_page.dart';
import '../settlement/settlement_page.dart';
import 'claim_detail_page.dart';
import 'claim_form_page.dart';
import 'dock_utama.dart';

final _dateFmt = DateFormat('dd/MM/yy');

/// Halaman utama untuk layar sempit. Layar lebar memakai AdminShell.
///
/// Dua isi yang bergantian lewat dock di dasar: daftar klaim garansi dan
/// Servisku. Tombol Klaim Baru ikut duduk di dock, menggantikan tombol
/// melayang yang dulu menutupi baris terakhir daftar.
class ClaimsPage extends ConsumerStatefulWidget {
  const ClaimsPage({super.key});

  @override
  ConsumerState<ClaimsPage> createState() => _ClaimsPageState();
}

class _ClaimsPageState extends ConsumerState<ClaimsPage> {
  TabUtama _tab = TabUtama.klaim;

  void _pindah(TabUtama t) {
    if (t != _tab) setState(() => _tab = t);
  }

  /// Klaim tinggal di sisi kiri dan Servisku di sisi kanan, seperti letak
  /// menunya di dock. Masing-masing masuk dan keluar lewat sisinya sendiri:
  /// menuju Servisku, Klaim keluar ke kiri dan Servisku datang dari kanan;
  /// kembali, sebaliknya. Searah dengan penanda di dock.
  ///
  /// Sisi ditentukan oleh isinya sendiri, bukan oleh arah perpindahan
  /// terakhir. AnimatedSwitcher menyimpan transisi isi lama sebagaimana
  /// dibangun saat isi itu masuk, jadi arah yang dibaca dari state akan
  /// basi tepat pada isi yang sedang keluar.
  Widget _transisi(Widget isi, Animation<double> gerak) {
    final sisi = isi.key == const ValueKey<TabUtama>(TabUtama.klaim)
        ? -1.0
        : 1.0;
    final geser = Tween<Offset>(
      begin: Offset(0.12 * sisi, 0),
      end: Offset.zero,
    );

    return FadeTransition(
      opacity: gerak,
      child: SlideTransition(position: gerak.drive(geser), child: isi),
    );
  }

  @override
  Widget build(BuildContext context) {
    final claims = ref.watch(claimsProvider);
    final jumlahServisku = ref.watch(notaBerjalanSayaProvider).length;
    final ruangBawah = DockUtama.ruangBawah(context);
    // Papan ketik yang terbuka menaikkan dock ke atasnya dan menutupi
    // separuh daftar; lebih baik dock menyingkir selama orang mengetik.
    final papanKetik = MediaQuery.viewInsetsOf(context).bottom > 0;
    final isAdmin = ref.watch(isAdminProvider);
    final adaPart = ref.watch(fiturTanyaHargaProvider);
    final profile = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.sm,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: DockUtama.lamaGerak(context) * 0.7,
              // Kolom judul rata kiri; tanpa ini judul lama dan baru
              // bertumpuk di tengah selama bertukar.
              layoutBuilder: (sekarang, sebelumnya) => Stack(
                alignment: Alignment.centerLeft,
                children: [...sebelumnya, ?sekarang],
              ),
              child: Text(
                _tab == TabUtama.klaim ? 'Klaim Garansi' : 'Servisku',
                key: ValueKey<String>('judul-${_tab.name}'),
              ),
            ),
            if (profile != null)
              Text(
                '${profile.nama} — ${profile.role}'.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: context.warna.teksLembut,
                ),
              ),
          ],
        ),
        actions: [
          const IndikatorKoneksi(),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            position: PopupMenuPosition.under,
            onSelected: (v) {
              switch (v) {
                case 'servis':
                  _push(context, const ServicePage());
                case 'part':
                  _push(context, const PartsPage());
                case 'pekerjaanku':
                  _push(context, const MyWorkPage());
                case 'rekap':
                  _push(context, const ReportsPage());
                case 'rekap_brand':
                  _push(context, const SettlementPage());
                case 'pengaturan':
                  _push(context, const SettingsPage());
                case 'keluar':
                  ref.read(supabaseProvider).auth.signOut();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'servis', child: Text('Servis')),
              // Sedang disimpan -- lihat fiturTanyaHargaProvider.
              if (adaPart)
                const PopupMenuItem(value: 'part', child: Text('Part')),
              const PopupMenuItem(
                value: 'pekerjaanku',
                child: Text('Pekerjaanku'),
              ),
              if (isAdmin) ...[
                const PopupMenuItem(value: 'rekap', child: Text('Rekap')),
                const PopupMenuItem(
                  value: 'rekap_brand',
                  child: Text('Rekap Brand'),
                ),
                const PopupMenuItem(
                  value: 'pengaturan',
                  child: Text('Pengaturan'),
                ),
              ],
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'keluar', child: Text('Keluar')),
            ],
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            // Dipotong: isi yang sedang bergeser tidak boleh menyembul di
            // luar tepi halaman.
            child: ClipRect(
              child: AnimatedSwitcher(
                duration: DockUtama.lamaGerak(context),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeOutCubic,
                transitionBuilder: _transisi,
                // Memenuhi ruang, bukan menyusut ke isinya: bawaannya
                // menaruh anak di tengah dengan batas longgar, dan kolom
                // saringan jadi selebar teks terpanjangnya.
                layoutBuilder: (sekarang, sebelumnya) => Stack(
                  fit: StackFit.expand,
                  children: [...sebelumnya, ?sekarang],
                ),
                child: _tab == TabUtama.klaim
                    ? _tabKlaim(claims, ruangBawah)
                    : ServiskuView(
                        key: const ValueKey<TabUtama>(TabUtama.servisku),
                        ruangBawah: ruangBawah,
                      ),
              ),
            ),
          ),
          Positioned(
            left: AppSpacing.sm - 4,
            right: AppSpacing.sm - 4,
            bottom: DockUtama.jarak + MediaQuery.paddingOf(context).bottom,
            child: Align(
              alignment: Alignment.bottomCenter,
              heightFactor: 1,
              child: IgnorePointer(
                ignoring: papanKetik,
                child: AnimatedSlide(
                  offset: papanKetik ? const Offset(0, 1.6) : Offset.zero,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  child: AnimatedOpacity(
                    opacity: papanKetik ? 0 : 1,
                    duration: const Duration(milliseconds: 180),
                    child: DockUtama(
                      tab: _tab,
                      jumlahServisku: jumlahServisku,
                      onTab: _pindah,
                      onKlaimBaru: () => _push(context, const ClaimFormPage()),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabKlaim(AsyncValue<List<Claim>> claims, double ruangBawah) {
    return Column(
      key: const ValueKey<TabUtama>(TabUtama.klaim),
      children: [
        const _FilterBar(),
        Expanded(
          // Tarik ke bawah untuk memasang ulang langganannya. Perubahan
          // memang datang sendiri, tetapi saat itu tidak terjadi -- sinyal
          // yang baru pulih, aplikasi yang lama tertidur -- orang butuh
          // cara memaksanya tanpa harus menutup aplikasi.
          child: RefreshIndicator(
            onRefresh: () async {
              segarkanData(ref);
              await ref.read(allClaimsProvider.future);
            },
            child: claims.when(
              loading: () => const Center(
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (e, _) => GagalMuat(e),
              data: (list) => list.isEmpty
                  ? ListView(
                      // Tetap ListView walau kosong: RefreshIndicator hanya
                      // bekerja di atas sesuatu yang bisa digulir, dan
                      // justru saat daftarnya kosong orang paling ingin
                      // mencoba menyegarkan.
                      children: [
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.6,
                          child: EmptyState(
                            icon: Icons.inbox_outlined,
                            title: 'Belum ada klaim',
                            description:
                                'Klaim yang kamu catat akan muncul di '
                                'sini, dan langsung terlihat di perangkat '
                                'lain.',
                            action: OutlinedButton(
                              onPressed: () =>
                                  _push(context, const ClaimFormPage()),
                              child: const Text('CATAT KLAIM PERTAMA'),
                            ),
                          ),
                        ),
                      ],
                    )
                  : _ClaimCards(list, ruangBawah: ruangBawah),
            ),
          ),
        ),
      ],
    );
  }

  static void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}

class _FilterBar extends ConsumerStatefulWidget {
  const _FilterBar();

  @override
  ConsumerState<_FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends ConsumerState<_FilterBar> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _setQuery(String v) => ref
      .read(claimFilterProvider.notifier)
      .update((s) => s.copyWith(query: v));

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(claimFilterProvider);
    final brands = ref.watch(brandsProvider).valueOrNull ?? const <Brand>[];
    final counts = ref.watch(statusCountsProvider).valueOrNull ?? const {};

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.warna.teks)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        0,
        AppSpacing.sm,
        AppSpacing.s,
      ),
      child: Column(
        children: [
          TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: 'Cari nama, SN, RMA, telp',
              prefixIcon: Icon(
                Icons.search,
                size: 18,
                color: context.warna.teksLembut,
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 38),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (filter.query.isNotEmpty)
                    IconButton(
                      iconSize: 18,
                      color: context.warna.teksLembut,
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _search.clear();
                        _setQuery('');
                      },
                    ),
                  ScanFieldButton(
                    title: 'Pindai SN untuk mencari',
                    onScanned: (v) {
                      _search.text = v;
                      _setQuery(v);
                    },
                  ),
                ],
              ),
            ),
            onChanged: _setQuery,
          ),
          const SizedBox(height: AppSpacing.xs),
          // Di layar sempit, dua dropdown jauh lebih hemat ruang daripada
          // deretan chip yang harus digeser ke kanan.
          Row(
            children: [
              Expanded(
                child: _FilterDropdown<int?>(
                  value: filter.brandId,
                  placeholder: 'SEMUA BRAND',
                  items: [for (final b in brands) (b.id, b.nama.toUpperCase())],
                  onChanged: (v) => ref
                      .read(claimFilterProvider.notifier)
                      .update(
                        (s) => v == null
                            ? s.copyWith(clearBrand: true)
                            : s.copyWith(brandId: v),
                      ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _FilterDropdown<String?>(
                  value: filter.status,
                  placeholder: 'SEMUA STATUS',
                  items: [
                    for (final s in ClaimStatus.all)
                      (
                        s,
                        '${ClaimStatus.label(s).toUpperCase()}  ${counts[s] ?? 0}',
                      ),
                  ],
                  onChanged: (v) => ref
                      .read(claimFilterProvider.notifier)
                      .update(
                        (s) => v == null
                            ? s.copyWith(clearStatus: true)
                            : s.copyWith(status: v),
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.value,
    required this.placeholder,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final String placeholder;
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
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
          onChanged: (v) => onChanged(v as T),
          items: [
            DropdownMenuItem<T>(value: null, child: Text(placeholder)),
            for (final (v, label) in items)
              DropdownMenuItem<T>(value: v, child: Text(label)),
          ],
        ),
      ),
    );
  }
}

class _ClaimCards extends ConsumerWidget {
  const _ClaimCards(this.items, {required this.ruangBawah});

  final List<Claim> items;

  /// Ruang di dasar daftar supaya baris terakhir tidak tertutup dock.
  final double ruangBawah;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brands = {
      for (final b
          in ref.watch(allBrandsProvider).valueOrNull ?? const <Brand>[])
        b.id: b.nama,
    };
    final techs = {
      for (final p
          in ref.watch(techniciansProvider).valueOrNull ?? const <Profile>[])
        p.id: p.nama,
    };

    return ListView.separated(
      // Kunci ini yang membuat letak gulirnya diingat waktu orang pindah
      // ke Servisku dan kembali.
      key: const PageStorageKey<String>('daftar-klaim'),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.s,
        AppSpacing.sm,
        ruangBawah + AppSpacing.s,
      ),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, i) => EntryAnimation(
        index: i,
        child: _ClaimCard(
          claim: items[i],
          brand: brands[items[i].brandId] ?? '—',
          technician: techs[items[i].teknisiId],
        ),
      ),
    );
  }
}

class _ClaimCard extends StatelessWidget {
  const _ClaimCard({
    required this.claim,
    required this.brand,
    required this.technician,
  });

  final Claim claim;
  final String brand;
  final String? technician;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => ClaimDetailPage(claim.id))),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    brand.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _dateFmt.format(claim.tanggal),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.4,
                      color: context.warna.teksLembut,
                    ),
                  ),
                  const Spacer(),
                  StatusChip(claim.status, compact: true, brand: brand),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                claim.namaPelanggan,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Text(
                claim.sn,
                style: TextStyle(
                  fontSize: 12,
                  color: context.warna.teksLembut,
                  letterSpacing: 0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if ((claim.keluhan ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  claim.keluhan!,
                  style: const TextStyle(fontSize: 13, height: 1.35),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: AppSpacing.xs),
              const Divider(),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      technician ?? 'Belum ditugaskan',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: technician == null
                            ? FontWeight.w400
                            : FontWeight.w600,
                        color: technician == null
                            ? context.warna.teksLembut
                            : context.warna.teks,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if ((claim.noPerbaikan ?? '').isNotEmpty)
                    Text(
                      claim.noPerbaikan!,
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 0.5,
                        color: context.warna.teksLembut,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
