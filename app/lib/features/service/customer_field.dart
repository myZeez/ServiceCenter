import 'package:flutter/material.dart';

import '../../core/local/database.dart';
import '../../core/theme.dart';
import '../../core/widgets/swiss_widgets.dart';

/// Kolom nama pelanggan yang sekaligus mencari data lama.
///
/// Daftar pilihannya selalu menampilkan kode, nama, DAN telepon bersamaan.
/// Nama sama tidak berarti orang sama; nomor teleponlah yang membedakan dua
/// pelanggan bernama serupa, dan tanpa menampilkannya operator tidak punya
/// cara membedakan mereka.
class CustomerField extends StatelessWidget {
  const CustomerField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.pelanggan,
    required this.terpilih,
    required this.onPilih,
    required this.onBaru,
    this.readOnly = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final List<CustomerEntry> pelanggan;

  /// Pelanggan yang sedang tertaut, bila ada.
  final CustomerEntry? terpilih;

  final ValueChanged<CustomerEntry> onPilih;

  /// Dipanggil saat operator menegaskan ini orang baru.
  final VoidCallback onBaru;

  final bool readOnly;

  List<CustomerEntry> _cari(String teks) {
    final q = teks.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return pelanggan
        .where(
          (c) =>
              c.nama.toLowerCase().contains(q) ||
              (c.telp ?? '').contains(q) ||
              c.kode.toLowerCase().contains(q),
        )
        .take(8)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    // Peringatan muncul bila ada pelanggan bernama persis sama tetapi belum
    // ada yang dipilih. Tidak memblokir: bisa jadi memang orang berbeda.
    final kembar = terpilih == null
        ? pelanggan
            .where(
              (c) =>
                  c.nama.toLowerCase() ==
                  controller.text.trim().toLowerCase(),
            )
            .toList()
        : const <CustomerEntry>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LabeledField(
          label: 'Nama Pelanggan',
          required: true,
          hint: terpilih != null
              ? null
              : 'Ketik untuk mencari pelanggan lama, atau isi nama baru.',
          child: RawAutocomplete<CustomerEntry>(
            textEditingController: controller,
            focusNode: focusNode,
            optionsBuilder: (v) => readOnly ? const [] : _cari(v.text),
            displayStringForOption: (c) => c.nama,
            onSelected: onPilih,
            fieldViewBuilder: (context, ctrl, node, onSubmit) {
              return TextFormField(
                controller: ctrl,
                focusNode: node,
                readOnly: readOnly,
                textCapitalization: TextCapitalization.characters,
                onFieldSubmitted: (_) => onSubmit(),
                decoration: InputDecoration(
                  suffixIcon: terpilih == null
                      ? const Icon(
                          Icons.search,
                          size: 17,
                          color: AppColors.grey,
                        )
                      : IconButton(
                          tooltip: 'Lepas tautan pelanggan',
                          iconSize: 16,
                          color: AppColors.red,
                          icon: const Icon(Icons.link_off),
                          onPressed: readOnly ? null : onBaru,
                        ),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Nama wajib diisi'
                    : null,
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 0,
                  color: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.base),
                    side: const BorderSide(color: AppColors.black),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxHeight: 260,
                      maxWidth: 420,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: options.length,
                      separatorBuilder: (_, _) => const Divider(),
                      itemBuilder: (context, i) {
                        final c = options.elementAt(i);
                        return InkWell(
                          onTap: () => onSelected(c),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.s,
                              vertical: 9,
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 72,
                                  child: Text(
                                    c.kode,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                      color: AppColors.grey,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    c.nama,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Text(
                                  c.telp ?? '—',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (terpilih != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.link, size: 12, color: AppColors.blue),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Tertaut ke ${terpilih!.kode}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                    color: AppColors.blue,
                  ),
                ),
              ),
            ],
          ),
        ] else if (kembar.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: const BoxDecoration(
              color: Color(0x0DD82C2C),
              border: Border(left: BorderSide(color: AppColors.red, width: 3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sudah ada pelanggan bernama sama:',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.red,
                  ),
                ),
                for (final c in kembar.take(3))
                  Text(
                    '${c.kode} · ${c.telp ?? 'tanpa telepon'}',
                    style: const TextStyle(fontSize: 10.5, color: AppColors.red),
                  ),
                const SizedBox(height: 2),
                const Text(
                  'Pilih dari daftar kalau orangnya sama. Kalau berbeda, '
                  'lanjutkan — akan dibuat pelanggan baru.',
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.35,
                    color: AppColors.red,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
