import 'package:flutter/material.dart';

import '../../../core/data/models.dart';
import '../../../core/kaca/panel_kaca.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/swiss_widgets.dart';
import '../../service/service_status.dart';
import '../../service/waktu_masuk.dart';
import '../cari_nota.dart';

/// Kolom nama pelanggan pada klaim, yang sekaligus mencari notanya.
///
/// Bentuknya sengaja sama persis dengan kolom nama di formulir servis:
/// ketik, muncul daftar, pilih. Yang berbeda hanya isi daftarnya -- di
/// sana pelanggan, di sini nota servis yang belum punya klaim.
///
/// Daftar pilihannya menyebut nomor nota, unit, tanggal, DAN statusnya
/// sekaligus. Satu orang bisa punya beberapa unit di meja pada waktu yang
/// sama, dan nama saja tidak cukup untuk membedakannya.
class KolomNota extends StatelessWidget {
  const KolomNota({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.nota,
    required this.terpilih,
    required this.onPilih,
    required this.onLepas,
    this.readOnly = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  /// Seluruh nota servis. Penyaringannya di [cariNota].
  final List<ServiceOrderEntry> nota;

  /// Nota yang sedang tertaut, bila ada.
  final ServiceOrderEntry? terpilih;

  final ValueChanged<ServiceOrderEntry> onPilih;

  /// Dipanggil saat orangnya melepas tautan -- klaim ini ternyata bukan
  /// untuk nota itu, atau memang tidak ada notanya sama sekali.
  final VoidCallback onLepas;

  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LabeledField(
          label: 'Nama',
          required: true,
          hint: terpilih != null
              ? null
              : 'Ketik nama sesuai nota servisnya — datanya ikut tertarik '
                    'dari sana. Kalau memang belum ada notanya, isi saja '
                    'seperti biasa.',
          child: RawAutocomplete<ServiceOrderEntry>(
            textEditingController: controller,
            focusNode: focusNode,
            optionsBuilder: (v) => readOnly || terpilih != null
                ? const []
                : cariNota(nota, v.text),
            // Yang tertulis di kolomnya tetap nama pelanggan; nomor nota
            // dan unitnya muncul sebagai keterangan tautan di bawah.
            displayStringForOption: (n) => n.customerNama,
            onSelected: onPilih,
            fieldViewBuilder: (context, ctrl, node, onSubmit) => TextFormField(
              controller: ctrl,
              focusNode: node,
              readOnly: readOnly,
              textCapitalization: TextCapitalization.characters,
              onFieldSubmitted: (_) => onSubmit(),
              decoration: InputDecoration(
                suffixIcon: terpilih == null
                    ? Icon(
                        Icons.search,
                        size: 17,
                        color: context.warna.teksLembut,
                      )
                    : IconButton(
                        tooltip: 'Lepas tautan nota',
                        iconSize: 16,
                        color: context.warna.bahaya,
                        icon: const Icon(Icons.link_off),
                        onPressed: readOnly ? null : onLepas,
                      ),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
            ),
            optionsViewBuilder: (context, onSelected, options) => Align(
              alignment: Alignment.topLeft,
              // Melayang di atas formulir, jadi ia berkaca seperti menu
              // pilihan -- lihat PanelKaca. Bukan rute, jadi PengamatKaca
              // tidak melihatnya dan buramnya dibawa sendiri.
              child: PanelKaca(
                tingkat: TingkatKaca.tebal,
                radius: BorderRadius.circular(AppRadius.base),
                bayangan: true,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 280,
                    maxWidth: 460,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: options.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, i) {
                      final n = options.elementAt(i);
                      return InkWell(
                        onTap: () => onSelected(n),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.s,
                            vertical: 9,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      n.customerNama,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  ServiceStatusChip(n.status, compact: true),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                [
                                  n.noNota,
                                  [
                                    n.barangNama,
                                    ?n.barangType,
                                  ].where((s) => s.isNotEmpty).join(' '),
                                  tanggalJamMasuk(n.tanggalMasuk),
                                ].join('  ·  '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
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
            ),
          ),
        ),
        if (terpilih != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: context.warna.aksen.withValues(alpha: 0.05),
              border: Border(
                left: BorderSide(color: context.warna.aksen, width: 3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.link, size: 12, color: context.warna.aksen),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Tertaut ke nota ${terpilih!.noNota}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: context.warna.aksen,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                // Disebutkan sebelum disimpan, bukan sesudah. Perubahan
                // yang merembet ke layar lain harus terbaca di tempat
                // orang memutuskannya.
                Text(
                  'Begitu klaim ini disimpan, nota itu ditandai bergaransi '
                  'dan statusnya berjalan bersama klaim ini.',
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.35,
                    color: context.warna.aksen,
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
