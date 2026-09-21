import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/data/models.dart';
import '../../core/kaca/kepala_mengambang.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/gagal_muat.dart';
import '../../core/widgets/swiss_widgets.dart';
import 'service_page.dart';
import 'servisku.dart';

final _tgl = DateFormat('dd-MM-yyyy');

/// Sama dengan tanggal masuk di kartu, supaya dua tanggal di satu baris
/// terbaca sepasang.
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

/// Servisku: unit yang sedang dikerjakan atas namamu -- baru masuk sampai
/// menunggu part -- dan, lewat tombol di atasnya, yang sudah selesai dalam
/// tiga bulan terakhir.
///
/// Sekadar menyaring daftar Servis menurut teknisinya. Yang bisa diubah
/// dari sini sama persis dengan di sana: ketuk kartunya, dan lembar ubah
/// pekerjaan terbuka.
class ServiskuView extends ConsumerStatefulWidget {
  const ServiskuView({super.key, this.ruangBawah = 0});

  /// Ruang di dasar daftar untuk sesuatu yang melayang di atasnya.
  final double ruangBawah;

  @override
  ConsumerState<ServiskuView> createState() => _ServiskuViewState();
}

class _ServiskuViewState extends ConsumerState<ServiskuView> {
  _Tampilan _tampil = _Tampilan.berjalan;

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

    return KepalaMengambang(
      kepala: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
          data: (_) {
            if (dipilih.isEmpty) {
              return ListView(
                key: const PageStorageKey<String>('servisku-kosong'),
                padding: EdgeInsets.only(top: ruangAtas),
                children: [
                  SizedBox(
                    // Ada batas bawahnya: di layar pendek separuh tinggi
                    // tak cukup memuat ikon, judul, dan penjelasannya.
                    height: math.max(
                      360.0,
                      MediaQuery.sizeOf(context).height * 0.5,
                    ),
                    child: EmptyState(
                      icon: _tampil == _Tampilan.berjalan
                          ? Icons.build_outlined
                          : Icons.task_alt_outlined,
                      title: _tampil == _Tampilan.berjalan
                          ? 'Tidak ada unit yang sedang kamu kerjakan'
                          : 'Belum ada unit selesai',
                      description: _tampil == _Tampilan.berjalan
                          ? 'Unit yang ditugaskan kepadamu muncul di '
                                'sini sejak masuk sampai selesai.'
                          : 'Unit atas namamu yang selesai dalam tiga '
                                'bulan terakhir muncul di sini.',
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              key: PageStorageKey<String>('servisku-${_tampil.name}'),
              padding: EdgeInsets.only(
                top: ruangAtas,
                bottom: AppSpacing.md + widget.ruangBawah,
              ),
              itemCount: dipilih.length,
              itemBuilder: (context, i) => KartuNotaServis(
                nota: dipilih[i],
                teknisi: techs,
                keteranganBaris: _tampil == _Tampilan.selesai
                    ? 'Selesai ${_tglPendek.format(kapanSelesai(dipilih[i]))}'
                    : null,
              ),
            );
          },
        ),
      ),
    );
  }
}
