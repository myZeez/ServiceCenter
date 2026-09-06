import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/data/models.dart';
import '../../core/print/nota_template.dart';
import '../../core/print/raw_printer.dart';
import '../../core/data/galat.dart';
import '../../core/fitur.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/swiss_widgets.dart';
import '../parts/part_dialog.dart';
import '../scan/scan_page.dart';
import 'customer_field.dart';
import 'service_status.dart';

const _uuid = Uuid();
final _rp = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp',
  decimalDigits: 0,
);
final _tglFmt = DateFormat('dd MMM yyyy');
final _tglJamFmt = DateFormat('dd MMM yyyy · HH:mm');
final _iso = DateFormat('yyyy-MM-dd');

Future<void> showServiceDialog(
  BuildContext context, {
  ServiceOrderEntry? nota,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Tutup',
    barrierColor: const Color(0x33000000),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, _, _) => ServiceDialog(nota: nota),
    transitionBuilder: (context, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 8 * curved.value,
          sigmaY: 8 * curved.value,
        ),
        child: FadeTransition(
          opacity: curved,
          child: Transform.scale(
            scale: 0.985 + (0.015 * curved.value),
            child: child,
          ),
        ),
      );
    },
  );
}

/// Apakah biaya pada sebuah nota bergaransi perlu ditanyakan lebih dulu.
///
/// Aturan di toko: unit bergaransi tidak dikenakan biaya sama sekali --
/// perbaikannya ditanggung brand. Yang berbayar hanya layanan tambahan di
/// luar garansi, dan itu jarang. Jadi angka yang muncul pada nota
/// bergaransi hampir selalu salah ketik, bukan keputusan.
///
/// Bertanya, bukan menolak. Layanan tambahan memang ada, dan aturan yang
/// mengunci akan memaksa admin mencatatnya di tempat lain -- yang berarti
/// uang yang benar-benar masuk tidak terbaca di laporan mana pun.
///
/// Hanya saat angkanya berubah. Ditanyakan tiap kali nota yang sama
/// disimpan, pertanyaan ini berubah jadi tombol yang ditekan tanpa dibaca,
/// dan sesudah itu ia tidak menjaga apa-apa lagi.
bool perluKonfirmasiBiayaGaransi({
  required bool garansi,
  required double biaya,
  required double biayaLama,
}) => garansi && biaya > 0 && biaya != biayaLama;

class ServiceDialog extends ConsumerStatefulWidget {
  const ServiceDialog({super.key, this.nota});

  final ServiceOrderEntry? nota;

  bool get isNew => nota == null;

  @override
  ConsumerState<ServiceDialog> createState() => _ServiceDialogState();
}

class _ServiceDialogState extends ConsumerState<ServiceDialog> {
  final _formKey = GlobalKey<FormState>();

  final _nama = TextEditingController();
  final _telp = TextEditingController();
  final _barang = TextEditingController();
  final _type = TextEditingController();
  final _sn = TextEditingController();
  final _kelengkapan = TextEditingController();
  final _keluhan = TextEditingController();
  final _perbaikan = TextEditingController();
  final _biaya = TextEditingController();
  final _keterangan = TextEditingController();
  final _partReq = TextEditingController();

  final _namaFokus = FocusNode();

  /// Pelanggan lama yang tertaut. Null berarti akan dibuatkan yang baru.
  CustomerEntry? _pelanggan;

  String? _teknisiId;
  int? _brandId;
  DateTime? _estimasi;
  bool _garansi = false;

  /// Apakah nota baru ini sekalian membuka tanya harga part.
  ///
  /// Selama tidak dicentang, formulir ini bekerja persis seperti sebelum
  /// ada fitur tanya harga -- tidak ada kolom tambahan yang wajib, dan
  /// tidak ada baris lain yang ikut dibuat.
  bool _tanyaHarga = false;
  String? _partKeterangan;
  String? _partBaru;
  String? _claimBaru;
  String _status = ServiceStatus.masuk;
  String? _caraBayar;
  DateTime? _tanggalLunas;

  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final n = widget.nota;
    if (n == null) return;

    _nama.text = n.customerNama;
    _telp.text = n.customerTelp ?? '';
    _barang.text = n.barangNama;
    _type.text = n.barangType ?? '';
    _sn.text = n.barangSn ?? '';
    _kelengkapan.text = n.kelengkapan ?? '';
    _keluhan.text = n.keluhan ?? '';
    _perbaikan.text = n.perbaikan ?? '';
    _biaya.text = n.biaya == 0 ? '' : n.biaya.toInt().toString();
    _keterangan.text = n.keterangan ?? '';
    _teknisiId = n.teknisiId;
    _estimasi = n.estimasiSelesai;
    _garansi = n.garansi;
    _status = n.status;
    _caraBayar = n.caraBayar;
    _tanggalLunas = n.tanggalLunas;
  }

  @override
  void dispose() {
    for (final c in [
      _nama,
      _telp,
      _barang,
      _type,
      _sn,
      _kelengkapan,
      _keluhan,
      _perbaikan,
      _biaya,
      _keterangan,
      _partReq,
    ]) {
      c.dispose();
    }
    _namaFokus.dispose();
    super.dispose();
  }

  String? _kosongNull(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  /// Apakah tanda garansi pada nota ini masih boleh dinyalakan.
  ///
  /// Dua keadaan menutupnya, dan alasannya berbeda:
  ///
  ///   klaimnya sudah ada     melepasnya meninggalkan klaim yatim di
  ///                          halaman Klaim
  ///   sudah bertanda garansi tetapi tanpa klaim -- ini bentuk nota
  ///                          bergaransi di arsip 2026, yang klaimnya
  ///                          memang dicatat terpisah. Membiarkannya
  ///                          terbuka membuat sekadar membuka lalu
  ///                          menyimpan nota lama menerbitkan klaim baru
  ///                          yang tidak diminta siapa pun.
  bool get _bolehUbahGaransi =>
      widget.nota == null ||
      (!widget.nota!.garansi && widget.nota!.claimId == null);

  Future<bool> _biayaGaransiDisengaja(double biaya) async {
    if (!perluKonfirmasiBiayaGaransi(
      garansi: _garansi,
      biaya: biaya,
      biayaLama: widget.nota?.biaya ?? 0,
    )) {
      return true;
    }

    final lanjut = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Unit bergaransi, tetapi ada biaya'),
        content: Text(
          'Nota bergaransi biasanya tidak dikenakan biaya — perbaikannya '
          'ditanggung brand.\n\n'
          '${_rp.format(biaya)} ini hanya benar kalau memang ada layanan '
          'tambahan di luar garansi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(d).pop(false),
            child: const Text('PERIKSA LAGI'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(d).pop(true),
            child: const Text('ADA LAYANAN TAMBAHAN'),
          ),
        ],
      ),
    );

    return lanjut ?? false;
  }

  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) return;
    if (_garansi && _brandId == null && _bolehUbahGaransi) {
      setState(() => _error = 'Pilih brand untuk klaim garansinya.');
      return;
    }
    if (!await _biayaGaransiDisengaja(double.tryParse(_biaya.text) ?? 0)) {
      return;
    }
    if (!mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    final client = ref.read(supabaseProvider);
    final user = ref.read(currentUserProvider);

    try {
      // Pelanggan baru dibuatkan catatannya sendiri supaya kunjungan
      // berikutnya tinggal dipilih. Yang sudah tertaut tidak disentuh --
      // mengubah data master dari formulir nota berarti satu koreksi ketik
      // diam-diam mengubah riwayat pelanggan lain yang bernama sama.
      var customerId = _pelanggan?.id;
      if (customerId == null) {
        final baru = await client
            .from('customers')
            .insert({'nama': _nama.text.trim(), 'telp': _kosongNull(_telp)})
            .select()
            .single();
        customerId = baru['id'] as String;
      }

      String? claimId = widget.nota?.claimId;

      // Unit bergaransi menghasilkan dua catatan sekaligus: nota untuk
      // pelanggan, dan klaim untuk brand. Datanya diketik satu kali.
      final perluKlaim = _garansi && claimId == null && _bolehUbahGaransi;

      // Dibuat sekali lalu dipakai lagi kalau penyimpanannya diulang.
      // Klaimnya bisa saja sudah sampai server sebelum notanya gagal
      // tersimpan; dengan id yang sama, percobaan berikutnya menyunting
      // klaim yang itu juga alih-alih menerbitkan klaim kembar.
      if (perluKlaim) claimId = _claimBaru ??= _uuid.v4();

      Map<String, dynamic> isiKlaim() => {
        'id': claimId,
        // Tanggal masuk unitnya, bukan tanggal orang menyadarinya
        // bergaransi. Yang dijawab kolom ini adalah kapan unit ini
        // sampai di meja.
        'tanggal': (widget.nota?.tanggalMasuk ?? DateTime.now())
            .toUtc()
            .toIso8601String(),
        'brand_id': _brandId!,
        'nama_pelanggan': _nama.text.trim(),
        'telp': _kosongNull(_telp),
        'sn': _sn.text.trim(),
        'teknisi_id': _teknisiId,
        'keluhan': _kosongNull(_keluhan),
        'status': 'open',
        'created_by': user!.id,
      };

      // Pada nota baru, klaimnya disimpan lebih dulu: notanya menunjuk ke
      // baris ini, dan server menolak tautan ke baris yang belum ada.
      if (perluKlaim && widget.isNew) {
        await ref.read(databaseProvider).simpanClaim(isiKlaim());
      }

      final data = {
        'estimasi_selesai': _estimasi == null ? null : _iso.format(_estimasi!),
        'customer_nama': _nama.text.trim(),
        'customer_telp': _kosongNull(_telp),
        'customer_id': customerId,
        'operator_id': user?.id,
        'barang_nama': _barang.text.trim(),
        'barang_type': _kosongNull(_type),
        'barang_sn': _kosongNull(_sn),
        'kelengkapan': _kosongNull(_kelengkapan),
        'keluhan': _kosongNull(_keluhan),
        'teknisi_id': _teknisiId,
        'perbaikan': _kosongNull(_perbaikan),
        // Pada nota yang sudah ada, tanda garansi sengaja TIDAK lewat
        // sini. Penjaga kolom di server menolak siapa pun selain admin
        // mengubah dua kolom ini lewat update biasa; yang berhak
        // mengubahnya hanya tautkan_nota_ke_klaim() di bawah. Dikirim apa
        // adanya supaya nilainya tidak berbeda dari yang tersimpan --
        // penjaganya membandingkan nilai, bukan niat.
        'garansi': widget.isNew ? _garansi : widget.nota!.garansi,
        'claim_id': widget.isNew ? claimId : widget.nota!.claimId,
        'status': _status,
        'biaya': double.tryParse(_biaya.text) ?? 0,
        'cara_bayar': _caraBayar,
        'tanggal_lunas': _tanggalLunas == null
            ? null
            : _iso.format(_tanggalLunas!),
        'keterangan': _kosongNull(_keterangan),
      };

      String notaId;
      if (widget.isNew) {
        // Idnya diminta kembali karena tanya harga di bawah menunjuk ke
        // baris ini. Nomor notanya sendiri tetap ditetapkan server.
        final baru = await client
            .from('service_orders')
            .insert(data)
            .select('id')
            .single();
        notaId = baru['id'] as String;
      } else {
        notaId = widget.nota!.id;
        await client.from('service_orders').update(data).eq('id', notaId);
      }

      // Nota yang ternyata bergaransi. Klaimnya lahir belakangan, lalu
      // ditautkan lewat fungsi khusus di server -- satu-satunya jalan
      // yang boleh menyentuh garansi dan claim_id.
      //
      // Kalau langkah ini gagal, dialognya tidak ditutup dan galatnya
      // tampil. Menekan simpan sekali lagi aman: idnya sudah dibuat dan
      // dipakai ulang, penyimpanan klaimnya berupa upsert, dan penautan
      // ke klaim yang sama tidak ditolak.
      if (perluKlaim && !widget.isNew) {
        final db = ref.read(databaseProvider);
        await db.simpanClaim(isiKlaim());
        await db.tautkanNotaKeKlaim(notaId, claimId!);
      }

      // Tanya harga lahir SESUDAH notanya: barisnya menunjuk ke nota itu,
      // dan server menolak tautan ke baris yang belum ada.
      var tanyaHargaGagal = false;
      if (widget.isNew && _tanyaHarga) {
        // Id dibuat sekali lalu dipakai lagi bila penyimpanannya diulang,
        // sama seperti klaim garansi di atas.
        final idPart = _partBaru ??= _uuid.v4();
        try {
          await ref.read(databaseProvider).simpanPartOrder({
            'id': idPart,
            'customer_nama': _nama.text.trim(),
            'customer_telp': _kosongNull(_telp),
            'customer_id': customerId,
            'barang_type': [
              _barang.text.trim(),
              _type.text.trim(),
            ].where((s) => s.isNotEmpty).join(' '),
            'barang_sn': _kosongNull(_sn),
            'part_req': _partReq.text.trim(),
            'keterangan': _partKeterangan,
            'teknisi_id': _teknisiId,
            'service_order_id': notaId,
            'created_by': user!.id,
          });
        } catch (_) {
          // Notanya sudah terlanjur tersimpan. Kalau kegagalan ini
          // dilaporkan seperti kegagalan biasa, admin akan menekan simpan
          // sekali lagi dan menerbitkan nota kedua -- membakar satu nomor
          // nota yang dibaca pusat. Jadi dialognya tetap ditutup, dan yang
          // dikabarkan persis apa yang terjadi.
          tanyaHargaGagal = true;
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tanyaHargaGagal
                ? 'Nota tersimpan, tetapi tanya harganya gagal dibuat. '
                      'Buat dari halaman Tanya Harga — jangan simpan nota '
                      'ini lagi.'
                : (widget.isNew ? 'Nota tersimpan' : 'Nota diperbarui'),
          ),
          duration: Duration(seconds: tanyaHargaGagal ? 10 : 4),
        ),
      );
    } on PostgrestException catch (e) {
      setState(() => _error = pesanGalat(e));
    } catch (_) {
      setState(
        () => _error =
            'Gagal menyimpan. Membuat nota membutuhkan koneksi, '
            'karena nomornya ditetapkan server agar tidak kembar.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Nota lapis dicetak sekali; karbon di lapis bawah yang menghasilkan
  /// salinannya. Mencetak dua kali justru memboroskan kertas.
  Future<void> _cetak(JenisNota jenis) async {
    final n = widget.nota;
    if (n == null) return;

    final printer = ref.read(printerNamaProvider).valueOrNull ?? '';
    final lebar = ref.read(printerLebarProvider).valueOrNull ?? 32;
    final toko = ref.read(storeSettingsProvider).valueOrNull;

    final orang = {
      for (final p
          in ref.read(techniciansProvider).valueOrNull ?? const <Profile>[])
        p.id: p.nama,
    };
    final semuaProfil = await ref.read(databaseProvider).allProfiles();
    final operator = semuaProfil
        .where((p) => p.id == n.operatorId)
        .map((p) => p.nama)
        .firstOrNull;

    final galat = RawPrinter.kirim(
      printer,
      susunNota(
        nota: n,
        jenis: jenis,
        toko: toko,
        namaTeknisi: orang[n.teknisiId],
        namaOperator: operator,
        namaCaraBayar: ref.read(namaMetodeBayar(n.caraBayar)),
        lebar: lebar,
      ),
    );

    if (!mounted) return;
    if (galat != null) {
      setState(() => _error = galat);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${jenis.judul} dikirim ke printer')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final techs = ref.watch(pengerjaUntukProvider(_teknisiId));
    final brands = ref.watch(brandsProvider).valueOrNull ?? const <Brand>[];
    final size = MediaQuery.sizeOf(context);

    // Nota yang sedang disunting mungkin sudah tertaut; tautannya dicari
    // sekali saat daftar pelanggan tersedia.
    final idTertaut = widget.nota?.customerId;
    if (_pelanggan == null && idTertaut != null) {
      final daftar = ref.watch(customersProvider).valueOrNull;
      if (daftar != null) {
        for (final c in daftar) {
          if (c.id == idTertaut) {
            _pelanggan = c;
            break;
          }
        }
      }
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Material(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.base),
          clipBehavior: Clip.antiAlias,
          child: Container(
            width: 1060,
            constraints: BoxConstraints(maxHeight: size.height - 80),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.base),
              border: Border.all(color: const Color(0xFFE4E7E7)),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _header(),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.sm,
                        AppSpacing.s,
                        AppSpacing.sm,
                        AppSpacing.sm,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _kiri()),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(child: _kanan(techs, brands)),
                        ],
                      ),
                    ),
                  ),
                  _footer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final n = widget.nota;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.s,
        AppSpacing.s,
        AppSpacing.s,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.black, width: 1.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n == null ? 'Nota Masuk Baru' : 'Nota ${n.noNota}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  n == null
                      ? 'Nomor nota diberikan otomatis saat disimpan'
                      // Sampai jamnya, karena hari kerja berganti jam
                      // tutup: nota ini bisa tercatat sebagai nota besok
                      // walau tanggalnya hari ini.
                      : _tglJamFmt.format(n.tanggalMasuk),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          if (n != null) ...[
            ServiceStatusChip(n.status),
            const SizedBox(width: AppSpacing.s),
          ],
          IconButton(
            iconSize: 18,
            color: AppColors.grey,
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _kiri() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Pelanggan'),
        const SizedBox(height: AppSpacing.s),
        CustomerField(
          controller: _nama,
          focusNode: _namaFokus,
          pelanggan:
              ref.watch(customersProvider).valueOrNull ??
              const <CustomerEntry>[],
          terpilih: _pelanggan,
          onPilih: (c) => setState(() {
            _pelanggan = c;
            _nama.text = c.nama;
            if ((c.telp ?? '').isNotEmpty) _telp.text = c.telp!;
          }),
          onBaru: () => setState(() => _pelanggan = null),
        ),
        const SizedBox(height: AppSpacing.s),
        LabeledField(
          label: 'Telepon',
          child: TextFormField(
            controller: _telp,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(hintText: '0812-3456-7890'),
          ),
        ),

        const SizedBox(height: AppSpacing.sm),
        const SectionLabel('Barang'),
        const SizedBox(height: AppSpacing.s),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: LabeledField(
                label: 'Nama Barang',
                required: true,
                child: TextFormField(
                  controller: _barang,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(hintText: 'LAPTOP ASUS'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              flex: 2,
              child: LabeledField(
                label: 'Type',
                child: TextFormField(
                  controller: _type,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(hintText: 'X441BA'),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s),
        LabeledField(
          label: 'Nomor Seri',
          required: _garansi,
          hint: _garansi
              ? 'Brand mengenali unit dari nomor serinya. Klaim tanpa ini '
                    'tidak bisa diproses siapa pun.'
              : null,
          child: TextFormField(
            controller: _sn,
            textCapitalization: TextCapitalization.characters,
            // Wajib hanya saat unitnya diklaimkan. Servis biasa sering
            // masuk tanpa nomor seri terbaca -- stikernya sudah hilang atau
            // unitnya mati total -- dan itu tidak menghalangi perbaikan.
            validator: (v) => _garansi && (v ?? '').trim().isEmpty
                ? 'Nomor seri wajib untuk klaim garansi'
                : null,
            decoration: InputDecoration(
              suffixIcon: ScanFieldButton(
                onScanned: (v) => setState(() => _sn.text = v),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        LabeledField(
          label: 'Kelengkapan',
          hint: 'Yang ikut diserahkan bersama unitnya.',
          child: TextFormField(
            controller: _kelengkapan,
            maxLines: 2,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(hintText: 'ADAPTOR, TAS'),
          ),
        ),
      ],
    );
  }

  Widget _kanan(List<Profile> techs, List<Brand> brands) {
    final metode = ref.watch(metodeBayarProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Servis'),
        const SizedBox(height: AppSpacing.s),
        LabeledField(
          label: 'Kerusakan / Keluhan',
          child: TextFormField(
            controller: _keluhan,
            maxLines: 2,
            textCapitalization: TextCapitalization.characters,
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: LabeledField(
                label: 'Teknisi',
                hint: techs.isEmpty
                    ? 'Belum ada teknisi. Tambahkan di Pengaturan → Pengguna.'
                    : null,
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
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: LabeledField(
                label: 'Estimasi Selesai',
                child: OutlinedButton(
                  onPressed: () async {
                    final p = await showDatePicker(
                      context: context,
                      initialDate:
                          _estimasi ??
                          DateTime.now().add(const Duration(days: 3)),
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 365),
                      ),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (p != null) setState(() => _estimasi = p);
                  },
                  style: _tombolTanggal,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _estimasi == null ? '—' : _tglFmt.format(_estimasi!),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s),

        // Centang ini menentukan apakah unit juga diklaimkan ke brand.
        //
        // Tetap hidup setelah notanya tersimpan, dan itu bukan kelonggaran
        // melainkan urutan kerja yang sebenarnya: unit masuk sebagai
        // servis biasa, dibongkar, dan baru di situ ketahuan masih
        // bergaransi. Yang dikunci hanya nota yang klaimnya sudah ada --
        // melepasnya berarti meninggalkan klaim yatim di halaman Klaim.
        CheckboxListTile(
          value: _garansi,
          onChanged: _bolehUbahGaransi
              ? (v) => setState(() => _garansi = v ?? false)
              : null,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text(
            'Unit bergaransi',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            widget.nota?.claimId != null
                ? 'Klaimnya sudah dibuat. Buka di halaman Klaim untuk '
                      'mengubahnya.'
                : !_bolehUbahGaransi
                ? 'Sudah bertanda garansi. Klaimnya dicatat terpisah di '
                      'halaman Klaim.'
                : widget.isNew
                ? 'Klaim ke brand dibuat otomatis dari data ini.'
                : 'Ternyata garansi setelah dicek? Centang saja — klaimnya '
                      'dibuat saat nota ini disimpan.',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
        if (_garansi && _bolehUbahGaransi) ...[
          const SizedBox(height: AppSpacing.xs),
          LabeledField(
            label: 'Brand untuk Klaim',
            required: true,
            child: DropdownButtonFormField<int>(
              initialValue: _brandId,
              isExpanded: true,
              hint: const Text('Pilih brand'),
              items: [
                for (final b in brands)
                  DropdownMenuItem(value: b.id, child: Text(b.nama)),
              ],
              onChanged: (v) => setState(() => _brandId = v),
            ),
          ),
        ],

        // Sedang disimpan -- lihat fiturTanyaHargaProvider.
        if (ref.watch(fiturTanyaHargaProvider)) ...[
          const SizedBox(height: AppSpacing.xs),
          _tanyaHargaBagian(context),
        ],

        const SizedBox(height: AppSpacing.sm),
        const SectionLabel('Penyelesaian'),
        const SizedBox(height: AppSpacing.s),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: LabeledField(
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
                  onChanged: (v) => setState(() => _status = v!),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: LabeledField(
                label: 'Biaya',
                // Disebut di kolomnya, bukan cuma ditanyakan saat
                // menyimpan: yang paling murah adalah salah ketik yang
                // tidak jadi diketik.
                hint: _garansi
                    ? 'Unit bergaransi ditanggung brand — biasanya Rp0. '
                          'Isi hanya kalau ada layanan tambahan di luar '
                          'garansi.'
                    : null,
                child: TextFormField(
                  controller: _biaya,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  // Dibaca ulang supaya keterangan dan pertanyaan di atas
                  // ikut menyala begitu angkanya diketik.
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(prefixText: 'Rp '),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: LabeledField(
                label: 'Cara Bayar',
                child: DropdownButtonFormField<String>(
                  // Cara bayar nota lama selalu ikut, walau metodenya
                  // sudah dinonaktifkan: dropdown yang nilainya tidak ada
                  // di antara pilihannya melempar galat, dan nota yang
                  // sudah tercetak harus tetap menyebut yang di kertasnya.
                  initialValue: metode.any((m) => m.kode == _caraBayar)
                      ? _caraBayar
                      : null,
                  isExpanded: true,
                  hint: Text(_caraBayar ?? '—'),
                  items: [
                    for (final m in metode)
                      DropdownMenuItem(value: m.kode, child: Text(m.nama)),
                  ],
                  onChanged: (v) => setState(() => _caraBayar = v),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: LabeledField(
                label: 'Tanggal Lunas',
                child: OutlinedButton(
                  onPressed: () async {
                    final p = await showDatePicker(
                      context: context,
                      initialDate: _tanggalLunas ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (p != null) setState(() => _tanggalLunas = p);
                  },
                  style: _tombolTanggal,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _tanggalLunas == null
                          ? 'Belum lunas'
                          : _tglFmt.format(_tanggalLunas!),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: _tanggalLunas == null
                            ? AppColors.red
                            : AppColors.black,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s),
        LabeledField(
          label: 'Perbaikan yang Dilakukan',
          hint: 'Muncul di laporan pelunasan.',
          child: TextFormField(
            controller: _perbaikan,
            maxLines: 2,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              hintText: 'GANTI PASTA, INSTAL ULANG',
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        LabeledField(
          label: 'Keterangan',
          child: TextFormField(controller: _keterangan, maxLines: 2),
        ),
      ],
    );
  }

  /// Jalan pintas ke tanya harga part.
  ///
  /// Dua bentuk, karena momennya dua. Saat nota baru dibuat, kebutuhannya
  /// sudah kelihatan di meja depan -- cukup satu centang, dan barisnya
  /// ikut lahir bersama notanya. Setelah nota tersimpan, kebutuhan itu
  /// biasanya baru ketahuan sesudah teknisi membuka unitnya, dan yang
  /// dibutuhkan adalah formulir tanya harga yang sudah terisi sendiri.
  ///
  /// Keduanya membawa data yang sama dan menghasilkan baris yang sama;
  /// yang berbeda hanya kapan admin sempat memikirkannya.
  Widget _tanyaHargaBagian(BuildContext context) {
    if (widget.isNew) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          CheckboxListTile(
            value: _tanyaHarga,
            onChanged: (v) => setState(() => _tanyaHarga = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text(
              'Perlu tanya harga part',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'Baris tanya harga dibuat otomatis dari data ini. Harga dan '
              'modalnya diisi belakangan di halaman Tanya Harga.',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          if (_tanyaHarga) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: LabeledField(
                    label: 'Part yang Dicari',
                    required: true,
                    child: TextFormField(
                      controller: _partReq,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        hintText: 'LCD 14 SLIM 30 PIN',
                      ),
                      // Hanya wajib selama centangnya menyala. Validator
                      // yang tetap galak setelah centangnya dilepas akan
                      // memblokir penyimpanan nota biasa.
                      validator: (v) => _tanyaHarga && (v ?? '').trim().isEmpty
                          ? 'Sebutkan part yang dicari'
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: LabeledField(
                    label: 'Keterangan',
                    child: DropdownButtonFormField<String>(
                      initialValue: _partKeterangan,
                      isExpanded: true,
                      hint: const Text('—'),
                      items: const [
                        DropdownMenuItem(value: 'oem', child: Text('OEM')),
                        DropdownMenuItem(value: 'ori', child: Text('ORI')),
                        DropdownMenuItem(value: 'copy', child: Text('Copy')),
                      ],
                      onChanged: (v) => setState(() => _partKeterangan = v),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      );
    }

    // Nota yang sudah tersimpan. Kalau tanya harganya sudah pernah dibuat,
    // yang ditawarkan membukanya -- bukan membuat yang kedua dengan isi
    // yang sama persis.
    final sudahAda = ref.watch(tanyaHargaNotaProvider(widget.nota!.id));

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s),
      decoration: BoxDecoration(
        color: AppColors.lightGrey,
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              sudahAda == null
                  ? 'Ternyata perlu ganti part? Datanya dibawa dari nota '
                        'ini — tinggal sebut partnya.'
                  : 'Sudah ada tanya harga untuk nota ini: '
                        '${sudahAda.partReq}.',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          const SizedBox(width: AppSpacing.s),
          OutlinedButton.icon(
            onPressed: () => showPartDialog(
              context,
              pesanan: sudahAda,
              awal: sudahAda != null ? null : _awalTanyaHarga(),
            ),
            icon: const Icon(Icons.request_quote_outlined, size: 17),
            label: Text(
              sudahAda == null ? 'TANYA HARGA PART' : 'LIHAT TANYA HARGA',
            ),
          ),
        ],
      ),
    );
  }

  /// Isian yang dibawa ke formulir tanya harga.
  ///
  /// Diambil dari kolom yang sedang tampil, bukan dari baris yang
  /// tersimpan: yang dilihat admin di layar itulah yang ia maksud, dan
  /// koreksi ketik yang belum sempat disimpan tetap ikut.
  AwalTanyaHarga _awalTanyaHarga() => AwalTanyaHarga(
    notaId: widget.nota!.id,
    customerNama: _nama.text.trim(),
    customerTelp: _kosongNull(_telp),
    customerId: _pelanggan?.id,
    // Merek dan tipe digabung: di tanya harga keduanya satu kolom, dan
    // yang berguna saat mencari part adalah sebutan lengkap unitnya.
    barangType: [
      _barang.text.trim(),
      _type.text.trim(),
    ].where((s) => s.isNotEmpty).join(' '),
    barangSn: _kosongNull(_sn),
    teknisiId: _teknisiId,
  );

  Widget _footer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.s,
        AppSpacing.sm,
        AppSpacing.s,
      ),
      decoration: const BoxDecoration(
        color: AppColors.lightGrey,
        border: Border(top: BorderSide(color: Color(0xFFE4E7E7))),
      ),
      child: Row(
        children: [
          Expanded(
            child: _error != null
                ? Text(
                    _error!,
                    style: const TextStyle(
                      color: AppColors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                : Text(
                    'Membuat nota membutuhkan koneksi — nomornya ditetapkan '
                    'server agar tidak pernah kembar.',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
          ),
          // Cetak hanya untuk nota yang sudah tersimpan: sebelum itu
          // nomornya belum ada, dan nota tanpa nomor tidak ada gunanya.
          if (!widget.isNew && RawPrinter.didukung) ...[
            OutlinedButton(
              onPressed: _busy ? null : () => _cetak(JenisNota.masuk),
              child: const Text('CETAK MASUK'),
            ),
            const SizedBox(width: AppSpacing.xs),
            OutlinedButton(
              onPressed: _busy ? null : () => _cetak(JenisNota.keluar),
              child: const Text('CETAK KELUAR'),
            ),
            const SizedBox(width: AppSpacing.s),
          ],
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: const Text('BATAL'),
          ),
          const SizedBox(width: AppSpacing.xs),
          FilledButton(
            onPressed: _busy ? null : _simpan,
            child: _busy
                ? const SizedBox(
                    height: 14,
                    width: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.white,
                    ),
                  )
                : Text(widget.isNew ? 'SIMPAN NOTA' : 'SIMPAN PERUBAHAN'),
          ),
        ],
      ),
    );
  }
}

final _tombolTanggal = OutlinedButton.styleFrom(
  alignment: Alignment.centerLeft,
  side: const BorderSide(color: Color(0xFFCFD5D4), width: 1),
  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s, vertical: 13),
);
