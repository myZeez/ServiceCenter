import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/data/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/bento.dart';
import 'service_dialog.dart';
import 'service_status.dart';

final _rupiah = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp',
  decimalDigits: 0,
);
final _tanggal = DateFormat('dd/MM/yyyy');

/// Daftar tagihan yang belum dibayar. Piutang tetap masuk omzet utama karena
/// jasa sudah dihasilkan; halaman ini khusus untuk memantau penagihannya.
class PiutangView extends ConsumerWidget {
  const PiutangView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semua =
        ref.watch(serviceOrdersProvider).valueOrNull ??
        const <ServiceOrderEntry>[];
    final hanyaBaca = ref.watch(isAdminScProvider);
    final kodePiutang = {
      for (final m
          in ref.watch(allMetodeBayarProvider).valueOrNull ??
              const <MetodeBayar>[])
        if (m.piutang) m.kode,
    };
    final namaTeknisi = {
      for (final p
          in ref.watch(techniciansProvider).valueOrNull ?? const <Profile>[])
        p.id: p.nama,
    };

    // Nota yang masih dikerjakan belum menjadi tagihan. Yang tampil di sini
    // Piutang ditentukan oleh metode bayar, bukan tanggal lunas: unit cabang
    // memakai tanggal lunas sebagai tanggal buku saat dikirim.
    final piutang =
        semua
            .where(
              (n) =>
                  n.biaya > 0 &&
                  n.status != ServiceStatus.batal &&
                  kodePiutang.contains(n.caraBayar) &&
                  (n.status == ServiceStatus.selesai ||
                      n.status == ServiceStatus.diambil ||
                      n.status == 'dikirim_cabang'),
            )
            .toList()
          ..sort((a, b) {
            final tanggalA =
                a.tanggalSelesai ?? a.tanggalDiambil ?? a.tanggalMasuk;
            final tanggalB =
                b.tanggalSelesai ?? b.tanggalDiambil ?? b.tanggalMasuk;
            return tanggalA.compareTo(tanggalB);
          });
    final total = piutang.fold<double>(0, (nilai, n) => nilai + n.biaya);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageHeader(
            title: 'Piutang Servis',
            subtitle:
                'Nota selesai atau sudah diambil yang belum tercatat lunas',
          ),
          const SizedBox(height: AppSpacing.s),
          BentoCard(
            title: 'TOTAL PIUTANG',
            accent: context.warna.bahaya,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _rupiah.format(total),
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.2,
                    ),
                  ),
                ),
                Text(
                  '${piutang.length} NOTA',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          Expanded(
            child: piutang.isEmpty
                ? Center(
                    child: Text(
                      'Tidak ada piutang servis.',
                      style: TextStyle(color: context.warna.teksLembut),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: AppSpacing.s),
                    itemCount: piutang.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final nota = piutang[index];
                      final tanggal =
                          nota.tanggalSelesai ??
                          nota.tanggalDiambil ??
                          nota.tanggalMasuk;
                      return Material(
                        color: context.warna.permukaan,
                        borderRadius: BorderRadius.circular(AppRadius.base),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.base),
                          onTap: hanyaBaca
                              ? null
                              : () => showServiceDialog(context, nota: nota),
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        nota.noNota,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(nota.customerNama),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${nota.barangNama} · ${nota.perbaikan ?? nota.keluhan ?? '—'}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: context.warna.teksLembut,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.s),
                                SizedBox(
                                  width: 108,
                                  child: Text(
                                    namaTeknisi[nota.teknisiId] ?? '—',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: context.warna.teksLembut,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.s),
                                SizedBox(
                                  width: 90,
                                  child: Text(
                                    _tanggal.format(tanggal),
                                    style: TextStyle(
                                      color: context.warna.teksLembut,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.s),
                                SizedBox(
                                  width: 120,
                                  child: Text(
                                    _rupiah.format(nota.biaya),
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: context.warna.bahaya,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
