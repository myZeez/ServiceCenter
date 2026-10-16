import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/models.dart';
import '../../core/nota/kirim_cabang.dart';
import '../../core/providers.dart';
import '../../core/status.dart';
import '../../core/theme.dart';

/// Nilai status harus sama persis dengan enum service_status di Postgres.
class ServiceStatus {
  static const masuk = 'masuk';
  static const dikerjakan = 'dikerjakan';
  static const tungguPart = 'tunggu_part';

  /// Unit dikerjakan di cabang lain. Membawa cabang tujuan dan tanggal
  /// kirim -- lihat [keteranganKirim].
  static const dikirimCabang = statusDikirimCabang;
  static const selesai = 'selesai';
  static const diambil = 'diambil';
  static const batal = 'batal';

  static const all = [
    masuk,
    dikerjakan,
    tungguPart,
    dikirimCabang,
    selesai,
    diambil,
    batal,
  ];

  /// Unit yang pekerjaannya belum tuntas: sudah diterima, belum rampung.
  ///
  /// 'selesai' sengaja tidak termasuk -- pekerjaannya sudah rampung, yang
  /// tersisa hanya menunggu pelanggan datang mengambil, dan itu bukan lagi
  /// beban teknisi.
  ///
  /// Yang dikirim ke cabang ikut: unitnya tidak ada di rak, tetapi
  /// pekerjaannya belum selesai, dan tetap teknisi yang menerimanya dulu
  /// yang ditanya kalau pelanggan menelepon.
  static const berjalan = [masuk, dikerjakan, tungguPart, dikirimCabang];

  static bool sedangDikerjakan(String status) => berjalan.contains(status);

  static const _labels = {
    masuk: 'Masuk',
    dikerjakan: 'Dikerjakan',
    tungguPart: 'Tunggu Part',
    dikirimCabang: 'Dikirim ke Cabang',
    selesai: 'Selesai',
    diambil: 'Sudah Diambil',
    batal: 'Batal',
  };

  static const _filled = {
    masuk: false,
    dikerjakan: true,
    tungguPart: true,
    // Sama seperti Tunggu Part: unit yang tertahan di luar meja paling mudah
    // terlupakan justru karena tidak ada yang bisa dikerjakan atasnya.
    dikirimCabang: true,
    // Selesai tapi belum diambil justru perlu ditagih -- itu unit yang
    // menumpuk di rak dan uangnya belum masuk.
    selesai: true,
    diambil: false,
    batal: false,
  };

  static String label(String s) => _labels[s] ?? s;

  /// Kalimat yang dibaca di nota dan laporan -- lihat
  /// [keteranganKirimCabang].
  static String keteranganKirim(String cabang, DateTime tanggal) =>
      keteranganKirimCabang(cabang, tanggal);

  /// Mengikuti pola yang sama dengan status klaim: yang menuntut tindakan
  /// diberi bobot visual paling besar, yang sudah tuntas mundur ke
  /// belakang. Rupanya ikut palet yang sedang berlaku.
  static Color color(BuildContext context, String s) {
    final w = context.warna;
    return switch (s) {
      masuk || dikerjakan => w.aksen,
      tungguPart || dikirimCabang || selesai => w.bahaya,
      diambil => w.teks,
      _ => w.teksLembut,
    };
  }

  static bool isFilled(String s) => _filled[s] ?? false;
}

class ServiceStatusChip extends StatelessWidget {
  const ServiceStatusChip(
    this.status, {
    super.key,
    this.compact = false,
    this.cabang,
    this.tanggalKirim,
    this.biayaDikirimCabang,
  });

  final String status;
  final bool compact;

  /// Cabang tujuan dan tanggal kirim, hanya dipakai status Dikirim ke
  /// Cabang. Yang pertama menggantikan kata "Cabang" di chip; yang kedua
  /// muncul sebagai keterangan saat chip ditahan atau diarahi kursor.
  final String? cabang;
  final DateTime? tanggalKirim;
  final bool? biayaDikirimCabang;

  @override
  Widget build(BuildContext context) {
    final c = ServiceStatus.color(context, status);
    final filled = ServiceStatus.isFilled(status);

    final tujuan = (cabang ?? '').trim();
    final kirim = status == ServiceStatus.dikirimCabang && tujuan.isNotEmpty;
    final penandaBiaya = status == ServiceStatus.dikirimCabang
        ? switch (biayaDikirimCabang) {
            true => compact ? ' • BIAYA' : ' • BERBIAYA',
            false => compact ? ' • GRATIS' : ' • TANPA BIAYA',
            null => '',
          }
        : '';
    final teks = kirim
        ? "${compact ? 'Ke $tujuan' : 'Dikirim ke $tujuan'}$penandaBiaya"
        : ServiceStatus.label(status);

    final chip = Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? c : Colors.transparent,
        border: Border.all(color: c),
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: Text(
        teks.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: filled ? context.warna.kertas : c,
          fontSize: compact ? 9 : 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.7,
          height: 1.2,
        ),
      ),
    );

    if (!kirim || tanggalKirim == null) return chip;
    final biayaTooltip = switch (biayaDikirimCabang) {
      true => ' dengan biaya',
      false => ' tanpa biaya',
      null => '',
    };
    return Tooltip(
      message:
          ServiceStatus.keteranganKirim(tujuan, tanggalKirim!) + biayaTooltip,
      child: chip,
    );
  }
}

/// Status sebuah nota seperti yang dibaca di meja depan.
///
/// Status klaim brand dan status nota sengaja berdampingan, bukan saling
/// menggantikan. Yang pertama menjelaskan proses ke brand; yang kedua
/// menjelaskan posisi unit pelanggan: masih dikerjakan, dikirim ke cabang,
/// sudah selesai, atau sudah diambil.
class StatusNotaChip extends ConsumerWidget {
  const StatusNotaChip(this.nota, {super.key, this.compact = false});

  final ServiceOrderEntry nota;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final klaim = ref.watch(klaimBrandNotaProvider(nota.claimId));
    if (klaim == null) {
      return ServiceStatusChip(
        nota.status,
        compact: compact,
        cabang: nota.cabangTujuan,
        tanggalKirim: nota.tanggalKirim,
        biayaDikirimCabang: nota.biayaDikirimCabang,
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.end,
      children: [
        Tooltip(
          message: 'Status garansi',
          child: StatusChip(
            klaim.status,
            compact: compact,
            brand: ref.watch(namaBrandProvider)[klaim.brandId],
          ),
        ),
        Tooltip(
          message: 'Status nota',
          child: ServiceStatusChip(
            nota.status,
            compact: compact,
            cabang: nota.cabangTujuan,
            tanggalKirim: nota.tanggalKirim,
            biayaDikirimCabang: nota.biayaDikirimCabang,
          ),
        ),
      ],
    );
  }
}
