import 'package:intl/intl.dart';

import '../service/service_status.dart';

final _rupiah = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp',
  decimalDigits: 0,
);
final _tanggal = DateFormat('dd/MM/yyyy');
final _waktu = DateFormat('dd/MM/yyyy HH:mm');

const _labelKolom = {
  'estimasi_selesai': 'Estimasi selesai',
  'customer_nama': 'Nama pelanggan',
  'customer_telp': 'Telepon',
  'customer_email': 'Email',
  'customer_id': 'Kartu pelanggan',
  'barang_nama': 'Barang',
  'barang_type': 'Tipe',
  'barang_sn': 'Nomor seri',
  'kelengkapan': 'Kelengkapan',
  'keluhan': 'Keluhan',
  'teknisi_id': 'Teknisi',
  'status': 'Status',
  'cabang_tujuan': 'Cabang tujuan',
  'tanggal_kirim': 'Tanggal kirim',
  'biaya_dikirim_cabang': 'Biaya kirim cabang',
  'biaya': 'Biaya',
  'cara_bayar': 'Cara bayar',
  'tanggal_lunas': 'Tanggal lunas',
  'waktu_lunas': 'Waktu lunas',
  'tanggal_diambil': 'Tanggal keluar',
  'waktu_diambil': 'Waktu keluar',
};

/// Satu kolom yang diminta berubah, dalam bahasa yang dibaca orang.
class BarisPerubahan {
  const BarisPerubahan({
    required this.label,
    required this.sebelum,
    required this.sesudah,
  });

  final String label;
  final String sebelum;
  final String sesudah;
}

List<BarisPerubahan> barisPerubahan({
  required Map<String, dynamic> perubahan,
  required Map<String, dynamic> sebelum,
  required Map<String, String> namaOrang,
  required Map<String, String> namaMetode,
}) {
  String nilai(String kolom, Object? isi) {
    if (isi == null || isi == '') return '—';
    return switch (kolom) {
      'biaya' => _rupiah.format(isi as num),
      'status' => ServiceStatus.label(isi as String),
      'teknisi_id' => namaOrang[isi] ?? '—',
      'cara_bayar' => namaMetode[isi] ?? '$isi',
      'customer_id' => 'Terhubung',
      'biaya_dikirim_cabang' => isi == true ? 'Ada biaya' : 'Tanpa biaya',
      'estimasi_selesai' ||
      'tanggal_kirim' ||
      'tanggal_lunas' ||
      'tanggal_diambil' => _tanggal.format(DateTime.parse(isi as String)),
      'waktu_lunas' ||
      'waktu_diambil' => _waktu.format(DateTime.parse(isi as String).toLocal()),
      _ => '$isi',
    };
  }

  return [
    for (final e in perubahan.entries)
      BarisPerubahan(
        label: _labelKolom[e.key] ?? e.key,
        sebelum: nilai(e.key, sebelum[e.key]),
        sesudah: nilai(e.key, e.value),
      ),
  ];
}
