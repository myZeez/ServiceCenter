import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/data/models.dart';
import '../../core/export/excel_export.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/bento.dart';
import '../../core/widgets/swiss_widgets.dart';
import 'service_dialog.dart';

final _partnerStatusProvider = StateProvider<String?>((ref) => null);
final _partnerCariProvider = StateProvider<String>((ref) => '');

final _rpPartnerView = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp',
  decimalDigits: 0,
);
final _tglPartner = DateFormat('dd/MM/yy');
final _periodePartner = DateFormat('dd MMM yyyy', 'id_ID');

/// Laporan pekerjaan yang dikerjakan pihak partner.
///
/// Kolom identitas pada layar ini sengaja dibaca dari nota sumber. Dengan
/// begitu nota dan laporan partner tidak punya dua versi nama/barang/tanggal.
class PartnerView extends ConsumerStatefulWidget {
  const PartnerView({super.key});

  @override
  ConsumerState<PartnerView> createState() => _PartnerViewState();
}

class _PartnerViewState extends ConsumerState<PartnerView> {
  final _search = TextEditingController();
  late DateTimeRange _periode;

  @override
  void initState() {
    super.initState();
    final sekarang = DateTime.now();
    _periode = DateTimeRange(
      start: DateTime(sekarang.year, sekarang.month, 1),
      end: DateTime(sekarang.year, sekarang.month + 1, 0),
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _dalamPeriode(DateTime waktu) {
    final tanggal = DateTime(waktu.year, waktu.month, waktu.day);
    return !tanggal.isBefore(_periode.start) && !tanggal.isAfter(_periode.end);
  }

  String get _labelPeriode =>
      '${_periodePartner.format(_periode.start)} — ${_periodePartner.format(_periode.end)}';

  Future<void> _pilihPeriode() async {
    final hasil = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 2, 12, 31),
      initialDateRange: _periode,
      helpText: 'PILIH PERIODE LAPORAN PARTNER',
      saveText: 'PAKAI PERIODE',
    );
    if (hasil != null && mounted) setState(() => _periode = hasil);
  }

  @override
  Widget build(BuildContext context) {
    final partner =
        ref.watch(partnerServicesProvider).valueOrNull ??
        const <PartnerServiceEntry>[];
    final nota = {
      for (final n
          in ref.watch(serviceOrdersProvider).valueOrNull ??
              const <ServiceOrderEntry>[])
        n.id: n,
    };
    final teknisi = {
      for (final p
          in ref.watch(techniciansProvider).valueOrNull ?? const <Profile>[])
        p.id: p.nama,
    };
    final status = ref.watch(_partnerStatusProvider);
    final cari = ref.watch(_partnerCariProvider).trim().toLowerCase();
    final periodeData = [
      for (final p in partner)
        if (nota.containsKey(p.serviceOrderId) && _dalamPeriode(p.createdAt)) p,
    ];
    final tampil = [
      for (final p in periodeData)
        if (status == null || p.status == status)
          if (cari.isEmpty || _cocok(p, nota[p.serviceOrderId]!, cari)) p,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final selesai = periodeData.where((p) => p.status == 'selesai').toList();
    final totalUp = selesai.fold<double>(
      0,
      (total, p) => total + nota[p.serviceOrderId]!.biaya,
    );
    final totalSelisih = selesai.fold<double>(
      0,
      (total, p) =>
          total + (p.hpp == null ? 0 : nota[p.serviceOrderId]!.biaya - p.hpp!),
    );

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: 'Kirim Partner',
            subtitle:
                '${periodeData.length} nota dikirim · ${selesai.length} selesai · periode berdasarkan tanggal dikirim',
            actions: [
              OutlinedButton.icon(
                onPressed: _pilihPeriode,
                icon: const Icon(Icons.date_range_outlined, size: 17),
                label: Text(_labelPeriode),
              ),
              const SizedBox(width: AppSpacing.xs),
              TombolExport(
                aktif: tampil.isNotEmpty,
                onExport: () => ExcelExport.partner(
                  data: tampil,
                  nota: nota,
                  periode: _labelPeriode,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              SizedBox(
                width: 290,
                child: TextField(
                  controller: _search,
                  onChanged: (v) =>
                      ref.read(_partnerCariProvider.notifier).state = v,
                  decoration: const InputDecoration(
                    hintText: 'Cari nota, nama, barang',
                    prefixIcon: Icon(Icons.search, size: 18),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  value: '${periodeData.length}',
                  label: 'Semua',
                  selected: status == null,
                  onTap: () =>
                      ref.read(_partnerStatusProvider.notifier).state = null,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: StatTile(
                  value:
                      '${periodeData.where((p) => p.status == 'dikirim').length}',
                  label: 'Dikirim',
                  accent: context.warna.aksen,
                  selected: status == 'dikirim',
                  onTap: () => ref.read(_partnerStatusProvider.notifier).state =
                      'dikirim',
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: StatTile(
                  value: '${selesai.length}',
                  label: 'Selesai',
                  accent: context.warna.aksen,
                  selected: status == 'selesai',
                  onTap: () => ref.read(_partnerStatusProvider.notifier).state =
                      'selesai',
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: StatTile(
                  value: _rpPartnerView.format(totalUp),
                  label: 'Up Biaya Selesai',
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: StatTile(
                  value: _rpPartnerView.format(totalSelisih),
                  label: 'Income / Selisih',
                  accent: totalSelisih < 0
                      ? context.warna.bahaya
                      : context.warna.aksen,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: context.warna.permukaan,
                borderRadius: BorderRadius.circular(AppRadius.base),
                border: Border.all(color: context.warna.garisHalus),
              ),
              child: tampil.isEmpty
                  ? const EmptyState(
                      icon: Icons.handshake_outlined,
                      title: 'Belum ada servis partner',
                      description:
                          'Buka detail nota lalu pilih KIRIM KE PARTNER.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.s),
                      itemCount: tampil.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: AppSpacing.s),
                      itemBuilder: (_, i) {
                        final p = tampil[i];
                        final n = nota[p.serviceOrderId]!;
                        return _PartnerCard(
                          partner: p,
                          nota: n,
                          namaTeknisi: teknisi[n.teknisiId] ?? '—',
                          onTap: () => showServiceDialog(context, nota: n),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  bool _cocok(PartnerServiceEntry p, ServiceOrderEntry n, String q) =>
      n.noNota.toLowerCase().contains(q) ||
      n.customerNama.toLowerCase().contains(q) ||
      n.barangNama.toLowerCase().contains(q) ||
      (n.barangType ?? '').toLowerCase().contains(q) ||
      (p.catatan ?? '').toLowerCase().contains(q);
}

class _PartnerCard extends StatelessWidget {
  const _PartnerCard({
    required this.partner,
    required this.nota,
    required this.namaTeknisi,
    required this.onTap,
  });

  final PartnerServiceEntry partner;
  final ServiceOrderEntry nota;
  final String namaTeknisi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selesai = partner.status == 'selesai';
    final warna = selesai ? context.warna.garansi : context.warna.aksen;
    final upBiaya = nota.biaya;
    final selisih = partner.hpp == null ? null : upBiaya - partner.hpp!;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.small),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 4, height: 72, color: warna),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nota.customerNama,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${nota.noNota} · ${nota.barangNama}',
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${(nota.barangType ?? '—')} · Teknisi: $namaTeknisi',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            _Tanggal(label: 'MASUK', nilai: nota.tanggalMasuk),
            _Tanggal(label: 'KELUAR', nilai: nota.tanggalDiambil),
            SizedBox(
              width: 104,
              child: Text(
                selesai ? 'SELESAI' : 'DIKIRIM',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: warna,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
            SizedBox(
              width: 100,
              child: Text(
                selesai ? _rpPartnerView.format(partner.hpp) : '—',
                textAlign: TextAlign.right,
              ),
            ),
            SizedBox(
              width: 110,
              child: Text(
                selesai ? _rpPartnerView.format(upBiaya) : '—',
                textAlign: TextAlign.right,
              ),
            ),
            SizedBox(
              width: 110,
              child: Text(
                selesai ? _rpPartnerView.format(selisih) : '—',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: (selisih ?? 0) < 0 ? context.warna.bahaya : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tanggal extends StatelessWidget {
  const _Tanggal({required this.label, required this.nilai});
  final String label;
  final DateTime? nilai;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 82,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        Text(
          nilai == null ? '—' : _tglPartner.format(nilai!),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}
