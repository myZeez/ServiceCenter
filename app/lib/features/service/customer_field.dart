import 'package:flutter/material.dart';

import '../../core/data/models.dart';
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
    this.buatKartuBaru = true,
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

  /// Apakah nama yang tidak tertaut akan menerbitkan kartu pelanggan baru
  /// saat disimpan.
  ///
  /// Benar pada nota baru. Salah saat menyunting nota yang sudah ada:
  /// namanya sudah tersimpan sebagai teks di nota itu, dan menyimpannya
  /// lagi tidak menerbitkan kartu siapa pun.
  ///
  /// Peringatan "sudah ada pelanggan bernama sama" di bawah hanya masuk
  /// akal pada keadaan yang pertama. Pada yang kedua ia memperingatkan
  /// penggandaan yang tidak akan pernah terjadi -- dan karena hampir
  /// seluruh nota di arsip memang tidak punya kartu pelanggan, peringatan
  /// itu muncul di hampir setiap nota lama yang dibuka.
  final bool buatKartuBaru;

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
    // Peringatan muncul bila ada pelanggan bernama persis sama, belum ada
    // yang dipilih, DAN menyimpan memang akan menerbitkan kartu baru.
    // Tidak memblokir: bisa jadi memang orang berbeda.
    List<CustomerEntry> kembarUntuk(String teks) =>
        (terpilih == null && buatKartuBaru)
        ? pelanggan
              .where((c) => c.nama.toLowerCase() == teks.trim().toLowerCase())
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
              : buatKartuBaru
              ? 'Ketik untuk mencari pelanggan lama, atau isi nama baru.'
              : 'Namanya tersimpan di nota ini. Pilih dari daftar hanya '
                    'kalau ingin menautkannya ke kartu pelanggan.',
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
                          color: context.warna.teksLembut,
                        )
                      : IconButton(
                          tooltip: 'Lepas tautan pelanggan',
                          iconSize: 16,
                          color: context.warna.bahaya,
                          icon: const Icon(Icons.link_off),
                          onPressed: readOnly ? null : onBaru,
                        ),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 0,
                  color: context.warna.permukaan,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.base),
                    side: const BorderSide(color: context.warna.teks),
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
                                      color: context.warna.teksLembut,
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
                                    color: context.warna.teksLembut,
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
              const Icon(Icons.link, size: 12, color: context.warna.aksen),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Tertaut ke ${terpilih!.kode}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                    color: context.warna.aksen,
                  ),
                ),
              ),
            ],
          ),
        ] else
          // Didengarkan langsung dari controller-nya, bukan dihitung
          // sekali saat induknya digambar. Kolom ini tidak memanggil
          // setState siapa pun saat diketik, jadi peringatan yang
          // bersandar pada gambar ulang induknya tidak pernah muncul saat
          // orang benar-benar mengetik nama baru -- ia hanya muncul pada
          // kolom yang sudah terisi sejak awal, yaitu justru keadaan yang
          // TIDAK perlu diperingatkan.
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, nilai, _) {
              final kembar = kembarUntuk(nilai.text);
              if (kembar.isEmpty) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  decoration: const BoxDecoration(
                    color: Color(0x0DD82C2C),
                    border: Border(
                      left: BorderSide(color: context.warna.bahaya, width: 3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sudah ada pelanggan bernama sama:',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: context.warna.bahaya,
                        ),
                      ),
                      for (final c in kembar.take(3))
                        Text(
                          '${c.kode} · ${c.telp ?? 'tanpa telepon'}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: context.warna.bahaya,
                          ),
                        ),
                      const SizedBox(height: 2),
                      const Text(
                        'Pilih dari daftar kalau orangnya sama. Kalau '
                        'berbeda, lanjutkan — akan dibuat pelanggan baru.',
                        style: TextStyle(
                          fontSize: 10,
                          height: 1.35,
                          color: context.warna.bahaya,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
