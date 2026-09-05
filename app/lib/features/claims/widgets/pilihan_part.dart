import 'package:flutter/material.dart';

import '../../../core/data/models.dart';

/// Satu baris pilihan jenis part di dalam dropdown.
///
/// Namanya di atas, kodenya kecil di bawah. Kode saja tidak cukup untuk
/// memilih -- ADPT baru berarti sesuatu setelah dibaca sebagai Adaptor --
/// tetapi kode itulah yang dipakai saat mencocokkan dengan brand, jadi ia
/// tetap terlihat tanpa harus ikut mengambil perhatian.
class PilihanPart extends StatelessWidget {
  const PilihanPart(this.part, {super.key});

  final PartType part;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          part.nama,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, height: 1.2),
        ),
        Text(
          part.kode,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}
