import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/data/galat.dart';
import '../../core/data/models.dart';
import '../../core/providers.dart';
import '../../core/status.dart';
import '../../core/theme.dart';
import '../../core/widgets/gagal_muat.dart';
import '../../core/widgets/koneksi.dart';
import '../../core/widgets/swiss_widgets.dart';
import 'kirim_cabang_fields.dart';
import 'service_status.dart';
import 'waktu_masuk.dart';

final _rp = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp',
  decimalDigits: 0,
);

/// Antrean servis di layar sempit.
///
/// Sebelumnya halaman ini hanya ada di layar lebar, jadi teknisi yang
/// memegang unitnya tidak punya cara menandai pekerjaannya selesai --
/// padahal dialah yang tahu kapan rampung. Yang bisa diubah dari sini
/// sengaja sedikit: status, catatan perbaikan, dan siapa yang mengerjakan.
/// Biaya dan data nota tetap urusan meja depan.
class ServicePage extends ConsumerStatefulWidget {
  const ServicePage({super.key});

  @override
  ConsumerState<ServicePage> createState() => _ServicePageState();
}

class _ServicePageState extends ConsumerState<ServicePage> {
  String? _status;

  @override
  Widget build(BuildContext context) {
    final nota = ref.watch(serviceOrdersProvider);
    final techs = {
      for (final p
          in ref.watch(techniciansProvider).valueOrNull ?? const <Profile>[])
        p.id: p.nama,
    };

    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.sm,
        title: const Text('Servis'),
        actions: const [
          IndikatorKoneksi(),
          SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: Column(
        children: [
          _Saringan(
            dipilih: _status,
            jumlah: _perStatus(nota.valueOrNull ?? const []),
            onPilih: (s) => setState(() => _status = s),
          ),
          Expanded(
            child: RefreshIndicator(
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
                data: (semua) {
                  final tampil = _status == null
                      ? semua
                      : semua.where((n) => n.status == _status).toList();

                  if (tampil.isEmpty) {
                    return ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.55,
                          child: EmptyState(
                            icon: Icons.receipt_long_outlined,
                            title: semua.isEmpty
                                ? 'Belum ada nota'
                                : 'Tidak ada nota berstatus ini',
                            description: semua.isEmpty
                                ? 'Nota dibuat saat pelanggan menyerahkan '
                                      'unitnya di meja depan.'
                                : 'Pilih status lain di atas.',
                          ),
                        ),
                      ],
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    itemCount: tampil.length,
                    itemBuilder: (context, i) =>
                        _KartuNota(nota: tampil[i], teknisi: techs),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Map<String, int> _perStatus(List<ServiceOrderEntry> l) {
    final h = <String, int>{};
    for (final n in l) {
      h.update(n.status, (v) => v + 1, ifAbsent: () => 1);
    }
    return h;
  }
}

class _Saringan extends StatelessWidget {
  const _Saringan({
    required this.dipilih,
    required this.jumlah,
    required this.onPilih,
  });

  final String? dipilih;
  final Map<String, int> jumlah;
  final ValueChanged<String?> onPilih;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.warna.teks)),
      ),
      padding: const EdgeInsets.only(bottom: AppSpacing.s),
      child: SizedBox(
        height: 34,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          children: [
            _Chip(
              label: 'SEMUA',
              aktif: dipilih == null,
              onTap: () => onPilih(null),
            ),
            for (final s in ServiceStatus.all)
              if ((jumlah[s] ?? 0) > 0)
                _Chip(
                  label:
                      '${ServiceStatus.label(s).toUpperCase()}  '
                      '${jumlah[s]}',
                  aktif: dipilih == s,
                  onTap: () => onPilih(s),
                ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.aktif, required this.onTap});

  final String label;
  final bool aktif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: aktif ? context.warna.teks : context.warna.permukaan,
            border: Border.all(color: context.warna.teks),
            borderRadius: BorderRadius.circular(AppRadius.small),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: aktif ? context.warna.permukaan : context.warna.teks,
            ),
          ),
        ),
      ),
    );
  }
}

class _KartuNota extends ConsumerWidget {
  const _KartuNota({required this.nota, required this.teknisi});

  final ServiceOrderEntry nota;
  final Map<String, String> teknisi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => _bukaUbah(context, ref, nota),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.s,
        ),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.warna.garisHalus)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    nota.noNota,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                StatusNotaChip(nota, compact: true),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              nota.customerNama,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              [
                nota.barangNama,
                if ((nota.barangType ?? '').isNotEmpty) nota.barangType!,
              ].join(' '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: context.warna.teksLembut),
            ),
            if ((nota.keluhan ?? '').isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                nota.keluhan!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5),
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  '${tanggalJamMasuk(nota.tanggalMasuk)}  ·  '
                  '${teknisi[nota.teknisiId] ?? 'belum ada teknisi'}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const Spacer(),
                if (nota.biaya > 0)
                  Text(
                    _rp.format(nota.biaya),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Lembar ubah pekerjaan. Sengaja hanya memuat yang boleh disentuh teknisi,
/// supaya tidak ada kolom yang bisa diketik lalu ditolak server.
Future<void> _bukaUbah(
  BuildContext context,
  WidgetRef ref,
  ServiceOrderEntry nota,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.warna.permukaan,
    builder: (_) => _UbahKerjaan(nota: nota),
  );
}

class _UbahKerjaan extends ConsumerStatefulWidget {
  const _UbahKerjaan({required this.nota});

  final ServiceOrderEntry nota;

  @override
  ConsumerState<_UbahKerjaan> createState() => _UbahKerjaanState();
}

class _UbahKerjaanState extends ConsumerState<_UbahKerjaan> {
  late String _status = widget.nota.status;
  late String? _teknisiId = widget.nota.teknisiId;

  /// Status klaim yang dipilih, pada nota garansi brand. Kosong berarti
  /// belum disentuh, dan yang belum disentuh tidak ditulis -- sama seperti
  /// di formulir nota lengkap.
  String? _statusKlaim;

  /// Cabang tujuan dan tanggal kirim, untuk status Dikirim ke Cabang.
  /// Tanggalnya diambil dari nota hanya kalau nota itu memang sedang
  /// dalam pengiriman; selain itu hari ini.
  late String? _cabang = widget.nota.cabangTujuan;
  late DateTime _tanggalKirim =
      widget.nota.status == ServiceStatus.dikirimCabang &&
          widget.nota.tanggalKirim != null
      ? widget.nota.tanggalKirim!
      : hariIniKalender();

  late final _perbaikan = TextEditingController(
    text: widget.nota.perbaikan ?? '',
  );
  late final _keterangan = TextEditingController(
    text: widget.nota.keterangan ?? '',
  );

  /// Keluhan garansi -- milik klaimnya, bukan nota ini. Diisi sekali saat
  /// klaimnya pertama kali tersedia, lalu dibiarkan milik yang mengetik.
  final _keluhanGaransi = TextEditingController();
  String? _keluhanGaransiDari;

  bool _busy = false;

  @override
  void dispose() {
    _perbaikan.dispose();
    _keterangan.dispose();
    _keluhanGaransi.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    final klaim = ref.read(klaimBrandNotaProvider(widget.nota.claimId));
    final kirim = klaim == null && _status == ServiceStatus.dikirimCabang;

    // Lembar ini bukan Form, jadi cabang yang belum dipilih dicegat di
    // sini -- server menolaknya juga, tetapi dengan pesan yang tidak
    // menyebut cabang sama sekali.
    if (kirim && (_cabang == null || _cabang!.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih cabang tujuan dulu.')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final db = ref.read(databaseProvider);
      await db.ubahNota(widget.nota.id, {
        // Nota garansi brand: status notanya diturunkan server dari klaim.
        if (klaim == null) 'status': _status,
        // Cabang dan tanggal hanya ditulis saat statusnya Dikirim ke
        // Cabang; di status lain dibiarkan sebagai jejak.
        if (kirim) ...{
          'cabang_tujuan': _cabang,
          'tanggal_kirim': DateFormat('yyyy-MM-dd').format(_tanggalKirim),
        },
        'teknisi_id': _teknisiId,
        'perbaikan': _perbaikan.text.trim().isEmpty
            ? null
            : _perbaikan.text.trim(),
        'keterangan': _keterangan.text.trim().isEmpty
            ? null
            : _keterangan.text.trim(),
      });
      if (klaim != null) {
        final statusKlaim = _statusKlaim;
        final t = _keluhanGaransi.text.trim();
        final keluhanGaransi = t.isEmpty ? null : t;
        final perubahan = {
          if (statusKlaim != null && statusKlaim != klaim.status)
            'status': statusKlaim,
          if (_keluhanGaransiDari == klaim.id &&
              keluhanGaransi != klaim.keluhan)
            'keluhan': keluhanGaransi,
        };
        if (perubahan.isNotEmpty) await db.ubahClaim(klaim.id, perubahan);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(pesanGalat(e)),
          duration: const Duration(seconds: 8),
        ),
      );
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Pekerjaan diperbarui')));
  }

  @override
  Widget build(BuildContext context) {
    final techs =
        ref.watch(techniciansProvider).valueOrNull ?? const <Profile>[];
    // Diikuti, bukan dibaca sekali: daftar klaim bisa belum termuat saat
    // lembar ini dibuka.
    final klaim = ref.watch(klaimBrandNotaProvider(widget.nota.claimId));
    if (klaim != null && _keluhanGaransiDari != klaim.id) {
      _keluhanGaransiDari = klaim.id;
      _keluhanGaransi.text = klaim.keluhan ?? '';
    }
    final keluhanPelanggan = (widget.nota.keluhan ?? '').trim();

    // Bisa digulir: nota garansi punya satu kolom lebih banyak, dan begitu
    // papan ketik terbuka layar HP tidak lagi cukup memuat semuanya.
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: AppSpacing.sm,
        right: AppSpacing.sm,
        top: AppSpacing.sm,
        // Menyisakan ruang untuk papan ketik saat kolom catatan diisi.
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.nota.noNota,
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 2),
          Text(
            widget.nota.customerNama,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.sm),

          if (klaim == null)
            LabeledField(
              label: 'Status',
              child: DropdownButtonFormField<String>(
                initialValue: _status,
                isExpanded: true,
                items: [
                  for (final s in ServiceStatus.all)
                    DropdownMenuItem(
                      value: s,
                      child: Text(ServiceStatus.label(s)),
                    ),
                ],
                onChanged: (v) => setState(() {
                  if (v == null) return;
                  // Dikirim ke Cabang dari status lain berarti unitnya
                  // dikirim sekarang, bukan pada tanggal pengiriman lama
                  // yang masih tersimpan sebagai jejak.
                  if (v == ServiceStatus.dikirimCabang &&
                      widget.nota.status != ServiceStatus.dikirimCabang) {
                    _tanggalKirim = hariIniKalender();
                  }
                  _status = v;
                }),
              ),
            )
          else
            LabeledField(
              label: 'Status Garansi',
              hint: 'Ikut mengubah status klaimnya.',
              child: DropdownButtonFormField<String>(
                key: ValueKey(klaim.id),
                initialValue: _statusKlaim ?? klaim.status,
                isExpanded: true,
                items: [
                  for (final s in ClaimStatus.all)
                    DropdownMenuItem(
                      value: s,
                      child: Text(
                        ClaimStatus.label(
                          s,
                          brand: ref.watch(namaBrandProvider)[klaim.brandId],
                        ),
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _statusKlaim = v),
              ),
            ),
          if (klaim == null && _status == ServiceStatus.dikirimCabang) ...[
            const SizedBox(height: AppSpacing.s),
            KirimCabangFields(
              cabang: _cabang,
              tanggal: _tanggalKirim,
              onCabang: (v) => setState(() => _cabang = v),
              onTanggal: (d) => setState(() => _tanggalKirim = d),
            ),
          ],
          const SizedBox(height: AppSpacing.s),

          if (klaim != null) ...[
            LabeledField(
              label: 'Keluhan Garansi',
              // Keluhan pelanggan disebut sebagai pembanding, bukan disalin:
              // yang ditulis di sini adalah hasil pengecekan, dan itu yang
              // dibaca brand di laporan garansi.
              hint: keluhanPelanggan.isEmpty
                  ? 'Hasil pengecekanmu — dipakai di laporan garansi.'
                  : 'Keluhan pelanggan: $keluhanPelanggan',
              child: TextField(
                controller: _keluhanGaransi,
                maxLines: 2,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(hintText: 'NO POWER'),
              ),
            ),
            const SizedBox(height: AppSpacing.s),
          ],

          LabeledField(
            label: 'Teknisi',
            child: DropdownButtonFormField<String>(
              initialValue: _teknisiId,
              isExpanded: true,
              hint: const Text('Pilih'),
              items: [
                for (final t in techs)
                  DropdownMenuItem(value: t.id, child: Text(t.nama)),
              ],
              onChanged: (v) => setState(() => _teknisiId = v),
            ),
          ),
          const SizedBox(height: AppSpacing.s),

          LabeledField(
            label: 'Perbaikan',
            hint: 'Apa yang dikerjakan pada unit ini.',
            child: TextField(
              controller: _perbaikan,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          const SizedBox(height: AppSpacing.s),

          LabeledField(
            label: 'Catatan',
            hint: 'Hal lain yang perlu dicatat tentang unit ini.',
            child: TextField(
              controller: _keterangan,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          const SizedBox(height: AppSpacing.s),

          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: context.warna.aksen.withValues(alpha: 0.05),
              border: Border(
                left: BorderSide(color: context.warna.aksen, width: 3),
              ),
            ),
            child: Text(
              'Biaya, cara bayar, dan data pelanggan diubah dari meja depan.',
              style: TextStyle(
                fontSize: 11,
                height: 1.4,
                color: context.warna.aksen,
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            onPressed: _busy ? null : _simpan,
            child: Text(_busy ? 'MENYIMPAN…' : 'SIMPAN'),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
      ),
    );
  }
}
