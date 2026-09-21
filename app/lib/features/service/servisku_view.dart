import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/data/models.dart';
import '../../core/kaca/kepala_mengambang.dart';
import '../../core/nota/cocok_cari.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/gagal_muat.dart';
import '../../core/widgets/swiss_widgets.dart';
import 'service_page.dart';
import 'servisku.dart';
import 'widgets/omset_saya_card.dart';

final _tgl = DateFormat('dd-MM-yyyy');
final _tglPendek = DateFormat('dd/MM/yy');

/// Nota yang sedang dipegang pengguna yang login. Kosong bila belum ada
/// yang login atau datanya belum sampai.
final notaBerjalanSayaProvider = Provider<List<ServiceOrderEntry>>(
  (ref) => notaBerjalanSaya(
    ref.watch(serviceOrdersProvider).valueOrNull ?? const [],
    ref.watch(currentUserProvider)?.id,
  ),
);

enum _Tampilan { berjalan, selesai }

/// Servisku menyatukan daftar unit pribadi, pencarian cepat, dan omset bulan
/// berjalan agar teknisi tidak perlu berpindah ke Pekerjaanku atau Servis.
class ServiskuView extends ConsumerStatefulWidget {
  const ServiskuView({super.key, this.ruangBawah = 0});

  final double ruangBawah;

  @override
  ConsumerState<ServiskuView> createState() => _ServiskuViewState();
}

class _ServiskuViewState extends ConsumerState<ServiskuView> {
  _Tampilan _tampil = _Tampilan.berjalan;
  final _pencarian = TextEditingController();
  String _kata = '';

  @override
  void dispose() {
    _pencarian.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nota = ref.watch(serviceOrdersProvider);
    final saya = ref.watch(currentUserProvider)?.id;
    final techs = {
      for (final p
          in ref.watch(techniciansProvider).valueOrNull ?? const <Profile>[])
        p.id: p.nama,
    };

    final semua = nota.valueOrNull ?? const <ServiceOrderEntry>[];
    final sekarang = DateTime.now();
    final berjalan = ref.watch(notaBerjalanSayaProvider);
    final selesai = notaSelesaiSaya(semua, saya, sekarang);
    final dipilih = _tampil == _Tampilan.berjalan ? berjalan : selesai;
    final tampil = [
      for (final n in dipilih)
        if (cocokCariNota(n, _kata)) n,
    ];
    final sedangMencari = _kata.trim().isNotEmpty;

    return KepalaMengambang(
      kepala: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PencarianServisku(
            controller: _pencarian,
            adaIsi: sedangMencari,
            onUbah: (v) => setState(() => _kata = v),
            onHapus: () {
              _pencarian.clear();
              setState(() => _kata = '');
            },
          ),
          Container(
            decoration: context.kaca != null
                ? null
                : BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: context.warna.teks),
                    ),
                  ),
            padding: const EdgeInsets.only(bottom: AppSpacing.s),
            child: SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                children: [
                  ChipSaringan(
                    label: 'SEDANG DIKERJAKAN  ${berjalan.length}',
                    aktif: _tampil == _Tampilan.berjalan,
                    onTap: () => setState(() => _tampil = _Tampilan.berjalan),
                  ),
                  ChipSaringan(
                    label: 'SUDAH SELESAI  ${selesai.length}',
                    aktif: _tampil == _Tampilan.selesai,
                    onTap: () => setState(() => _tampil = _Tampilan.selesai),
                  ),
                ],
              ),
            ),
          ),
          if (_tampil == _Tampilan.selesai)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.xs,
                AppSpacing.sm,
                AppSpacing.xs,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Selesai sejak ${_tgl.format(tigaBulanSebelum(sekarang))} '
                  '— tiga bulan terakhir',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ),
        ],
      ),
      isi: (context, ruangAtas) => RefreshIndicator(
        edgeOffset: ruangAtas,
        onRefresh: () async {
          segarkanData(ref);
          await ref.read(serviceOrdersProvider.future);
        },
        child: nota.when(
          loading: () => const Center(
            child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (e, _) => GagalMuat(e),
          data: (_) => ListView(
            key: PageStorageKey<String>('servisku-${_tampil.name}'),
            padding: EdgeInsets.only(
              top: ruangAtas + AppSpacing.s,
              bottom: AppSpacing.md + widget.ruangBawah,
            ),
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.s),
                child: OmsetSayaCard(),
              ),
              const SizedBox(height: AppSpacing.s),
              if (tampil.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  child: EmptyState(
                    icon: sedangMencari
                        ? Icons.search_off_outlined
                        : (_tampil == _Tampilan.berjalan
                              ? Icons.build_outlined
                              : Icons.task_alt_outlined),
                    title: sedangMencari
                        ? 'Tidak ada unit yang cocok'
                        : (_tampil == _Tampilan.berjalan
                              ? 'Tidak ada unit yang sedang kamu kerjakan'
                              : 'Belum ada unit selesai'),
                  ),
                )
              else
                for (final n in tampil)
                  KartuNotaServis(
                    nota: n,
                    teknisi: techs,
                    keteranganBaris: _tampil == _Tampilan.selesai
                        ? 'Selesai ${_tglPendek.format(kapanSelesai(n))}'
                        : null,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PencarianServisku extends StatelessWidget {
  const _PencarianServisku({
    required this.controller,
    required this.adaIsi,
    required this.onUbah,
    required this.onHapus,
  });

  final TextEditingController controller;
  final bool adaIsi;
  final ValueChanged<String> onUbah;
  final VoidCallback onHapus;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        0,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Cari no nota, nama, SN, telp',
          filled: context.kaca == null ? null : true,
          fillColor: context.kaca == null ? null : Colors.transparent,
          prefixIcon: Icon(
            Icons.search,
            size: 18,
            color: context.warna.teksLembut,
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 38),
          suffixIcon: adaIsi
              ? IconButton(
                  tooltip: 'Hapus kata pencarian',
                  iconSize: 18,
                  color: context.warna.teksLembut,
                  icon: const Icon(Icons.close),
                  onPressed: onHapus,
                )
              : null,
        ),
        onChanged: onUbah,
      ),
    );
  }
}
