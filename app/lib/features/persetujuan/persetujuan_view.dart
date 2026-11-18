import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/data/galat.dart';
import '../../core/data/models.dart';
import '../../core/kaca/overlay_kaca.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/bento.dart';
import '../service/service_dialog.dart';
import 'perubahan_nota.dart';

final _waktu = DateFormat('dd/MM/yyyy HH:mm');

/// Antrean perubahan nota yang sudah keluar.
///
/// Super admin memutuskan di sini. Admin melihat halaman yang sama untuk
/// memantau hasil pengajuannya, dan bisa menarik yang masih menunggu.
class PersetujuanView extends ConsumerWidget {
  const PersetujuanView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final superAdmin = ref.watch(isSuperAdminProvider);
    final semua =
        ref.watch(permintaanNotaProvider).valueOrNull ??
        const <PermintaanUbahNota>[];
    // Yang paling lama menunggu didahulukan.
    final menunggu = semua.where((p) => p.menunggu).toList().reversed.toList();
    final riwayat = semua.where((p) => !p.menunggu).toList();

    return DefaultTabController(
      length: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s,
          vertical: AppSpacing.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: 'Persetujuan',
              subtitle: superAdmin
                  ? 'Perubahan nota yang sudah keluar, menunggu keputusanmu'
                  : 'Perubahan nota yang diajukan ke super admin',
            ),
            const SizedBox(height: AppSpacing.s),
            Container(
              decoration: BoxDecoration(
                color: context.warna.permukaan,
                borderRadius: BorderRadius.circular(AppRadius.base),
                border: Border.all(color: context.warna.garisHalus),
              ),
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  Tab(text: 'MENUNGGU (${menunggu.length})'),
                  const Tab(text: 'RIWAYAT'),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            Expanded(
              child: TabBarView(
                children: [
                  _Daftar(
                    daftar: menunggu,
                    pesanKosong: 'Tidak ada permintaan yang menunggu.',
                  ),
                  _Daftar(
                    daftar: riwayat,
                    pesanKosong: 'Belum ada permintaan yang diputus.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PersetujuanPage extends StatelessWidget {
  const PersetujuanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.warna.teredam,
      body: const SafeArea(child: PersetujuanView()),
    );
  }
}

class _Daftar extends StatelessWidget {
  const _Daftar({required this.daftar, required this.pesanKosong});

  final List<PermintaanUbahNota> daftar;
  final String pesanKosong;

  @override
  Widget build(BuildContext context) {
    if (daftar.isEmpty) {
      return Center(
        child: Text(
          pesanKosong,
          style: TextStyle(color: context.warna.teksLembut),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: AppSpacing.s),
      itemCount: daftar.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, i) =>
          _Permintaan(key: ValueKey(daftar[i].id), permintaan: daftar[i]),
    );
  }
}

class _Permintaan extends ConsumerStatefulWidget {
  const _Permintaan({super.key, required this.permintaan});

  final PermintaanUbahNota permintaan;

  @override
  ConsumerState<_Permintaan> createState() => _PermintaanState();
}

class _PermintaanState extends ConsumerState<_Permintaan> {
  bool _busy = false;

  Future<void> _kerjakan(Future<void> Function() aksi, String berhasil) async {
    final pesan = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await aksi();
      pesan.showSnackBar(SnackBar(content: Text(berhasil)));
    } catch (e) {
      pesan.showSnackBar(SnackBar(content: Text(pesanGalat(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setujui() => _kerjakan(
    () => ref
        .read(databaseProvider)
        .putuskanPermintaanNota(widget.permintaan.id, setuju: true),
    'Perubahan disetujui dan diterapkan ke nota',
  );

  Future<void> _tolak() async {
    final catatan = await tampilkanDialog<String>(
      context: context,
      builder: (_) => const _DialogTolak(),
    );
    if (catatan == null) return;
    await _kerjakan(
      () => ref
          .read(databaseProvider)
          .putuskanPermintaanNota(
            widget.permintaan.id,
            setuju: false,
            catatan: catatan,
          ),
      'Permintaan ditolak',
    );
  }

  Future<void> _batalkan() => _kerjakan(
    () =>
        ref.read(databaseProvider).batalkanPermintaanNota(widget.permintaan.id),
    'Permintaan dibatalkan',
  );

  @override
  Widget build(BuildContext context) {
    final p = widget.permintaan;
    final superAdmin = ref.watch(isSuperAdminProvider);
    final saya = ref.watch(currentUserProvider)?.id;
    final namaOrang = {
      for (final o
          in ref.watch(allProfilesProvider).valueOrNull ?? const <Profile>[])
        o.id: o.nama,
    };
    final namaMetode = {
      for (final m
          in ref.watch(allMetodeBayarProvider).valueOrNull ??
              const <MetodeBayar>[])
        m.kode: m.nama,
    };
    ServiceOrderEntry? nota;
    for (final n
        in ref.watch(serviceOrdersProvider).valueOrNull ??
            const <ServiceOrderEntry>[]) {
      if (n.id == p.notaId) {
        nota = n;
        break;
      }
    }
    final baris = barisPerubahan(
      perubahan: p.perubahan,
      sebelum: p.sebelum,
      namaOrang: namaOrang,
      namaMetode: namaMetode,
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: context.warna.permukaan,
        borderRadius: BorderRadius.circular(AppRadius.base),
        border: Border.all(color: context.warna.garisHalus),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  [
                    p.noNota ?? '—',
                    if (nota != null) nota.customerNama,
                  ].join(' · '),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              _TandaStatus(status: p.status),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            'Diajukan ${namaOrang[p.diajukanOleh] ?? '—'} · '
            '${_waktu.format(p.diajukanPada.toLocal())}',
            style: TextStyle(fontSize: 12, color: context.warna.teksLembut),
          ),
          const SizedBox(height: AppSpacing.s),
          for (final b in baris)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${b.label}: ',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: '${b.sebelum} → ${b.sesudah}'),
                  ],
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ),
          const SizedBox(height: 4),
          Text('Alasan: ${p.alasan}', style: const TextStyle(fontSize: 13)),
          if (p.diputusPada != null) ...[
            const SizedBox(height: 4),
            Text(
              [
                '${namaOrang[p.diputusOleh] ?? '—'} · '
                    '${_waktu.format(p.diputusPada!.toLocal())}',
                if (p.catatanPutusan != null) p.catatanPutusan!,
              ].join(' · '),
              style: TextStyle(fontSize: 12, color: context.warna.teksLembut),
            ),
          ],
          if (p.menunggu || nota != null) ...[
            const SizedBox(height: AppSpacing.s),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                if (nota != null)
                  TextButton(
                    onPressed: () => showServiceDialog(context, nota: nota),
                    child: const Text('LIHAT NOTA'),
                  ),
                if (p.menunggu && !superAdmin && p.diajukanOleh == saya)
                  OutlinedButton(
                    onPressed: _busy ? null : _batalkan,
                    child: const Text('BATALKAN'),
                  ),
                if (p.menunggu && superAdmin) ...[
                  OutlinedButton(
                    onPressed: _busy ? null : _tolak,
                    child: const Text('TOLAK'),
                  ),
                  FilledButton(
                    onPressed: _busy ? null : _setujui,
                    child: const Text('SETUJUI'),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TandaStatus extends StatelessWidget {
  const _TandaStatus({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final warna = switch (status) {
      'disetujui' => context.warna.aksen,
      'ditolak' => context.warna.bahaya,
      _ => context.warna.teksLembut,
    };
    return Text(
      status.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: warna,
      ),
    );
  }
}

class _DialogTolak extends StatefulWidget {
  const _DialogTolak();

  @override
  State<_DialogTolak> createState() => _DialogTolakState();
}

class _DialogTolakState extends State<_DialogTolak> {
  final _catatan = TextEditingController();

  @override
  void dispose() {
    _catatan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tolak permintaan?'),
      content: SizedBox(
        width: 380,
        child: TextField(
          controller: _catatan,
          autofocus: true,
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Catatan untuk pengaju (boleh kosong)',
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('BATAL'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_catatan.text.trim()),
          child: const Text('TOLAK'),
        ),
      ],
    );
  }
}
