import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/data/models.dart';
import '../../core/data/galat.dart';
import '../../core/providers.dart';
import '../../core/status.dart';
import '../../core/theme.dart';
import '../../core/widgets/swiss_widgets.dart';
import '../scan/scan_page.dart';
import 'cari_nota.dart';
import 'widgets/kolom_nota.dart';
import 'widgets/pilihan_part.dart';

const _uuid = Uuid();
final _dateFmt = DateFormat('dd MMM yyyy');
final _stampFmt = DateFormat('dd MMM yyyy · HH:mm');

/// Membuka klaim sebagai lapisan di atas daftar, bukan halaman terpisah.
///
/// Daftar di belakangnya tetap terlihat samar, jadi tidak ada rasa
/// "berpindah tempat" -- yang mahal ketika admin membuka puluhan klaim
/// berturut-turut. [claim] null berarti membuat klaim baru.
Future<void> showClaimDialog(BuildContext context, {Claim? claim}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Tutup',
    barrierColor: const Color(0x33000000),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, _, _) => ClaimDialog(claim: claim),
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

class ClaimDialog extends ConsumerStatefulWidget {
  const ClaimDialog({super.key, this.claim});

  final Claim? claim;

  bool get isNew => claim == null;

  @override
  ConsumerState<ClaimDialog> createState() => _ClaimDialogState();
}

class _PartEntry {
  _PartEntry({this.existingId, this.typeId, String? sn})
    : sn = TextEditingController(text: sn ?? '');

  final String? existingId;
  int? typeId;
  final TextEditingController sn;

  void dispose() => sn.dispose();
}

class _ClaimDialogState extends ConsumerState<ClaimDialog> {
  final _formKey = GlobalKey<FormState>();

  final _nama = TextEditingController();
  final _telp = TextEditingController();
  final _email = TextEditingController();
  final _snUnit = TextEditingController();
  final _keluhan = TextEditingController();
  final _noPerbaikan = TextEditingController();
  final _catatan = TextEditingController();

  final _namaFokus = FocusNode();

  int? _brandId;
  String _jenis = ClaimJenis.brand;
  String? _teknisiId;
  String _status = ClaimStatus.open;
  late DateTime _tanggal;

  /// Nota servis yang akan ditandai bergaransi begitu klaim ini tersimpan.
  /// Lihat [KolomNota] untuk kenapa jalannya lewat sini.
  ServiceOrderEntry? _nota;

  /// Dibuat sekali. Id yang dibuat ulang tiap kali tombol simpan ditekan
  /// membuat percobaan kedua atas penyimpanan yang gagal separuh jalan
  /// menerbitkan klaim kembar alih-alih melanjutkan yang tadi.
  String? _idBaru;

  List<_PartEntry> _parts = [];
  final List<String> _removedPartIds = [];

  bool _ready = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final c = widget.claim;

    if (c == null) {
      _tanggal = DateTime.now();
      _parts = [_PartEntry()];
      _ready = true;
      return;
    }

    _tanggal = c.tanggal;
    _brandId = c.brandId;
    _jenis = c.jenis;
    _teknisiId = c.teknisiId;
    _status = c.status;
    _nama.text = c.namaPelanggan;
    _telp.text = c.telp ?? '';
    _email.text = c.email ?? '';
    _snUnit.text = c.sn;
    _keluhan.text = c.keluhan ?? '';
    _noPerbaikan.text = c.noPerbaikan ?? '';
    _catatan.text = c.catatan ?? '';
    _loadParts(c.id);
  }

  Future<void> _loadParts(String claimId) async {
    final rows = await ref.read(databaseProvider).partsOf(claimId);
    if (!mounted) return;
    setState(() {
      _parts = rows.isEmpty
          ? [_PartEntry()]
          : [
              for (final r in rows)
                _PartEntry(
                  existingId: r.id,
                  typeId: r.partTypeId,
                  sn: r.snBadPart,
                ),
            ];
      _ready = true;
    });
  }

  @override
  void dispose() {
    _nama.dispose();
    _telp.dispose();
    _email.dispose();
    _snUnit.dispose();
    _keluhan.dispose();
    _noPerbaikan.dispose();
    _catatan.dispose();
    _namaFokus.dispose();
    for (final p in _parts) {
      p.dispose();
    }
    super.dispose();
  }

  String? _nullIfEmpty(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  /// Mengambil alih isi formulir dari sebuah nota servis.
  ///
  /// Keluhan tidak ditimpa kalau sudah diketik: yang ada di layar biasanya
  /// hasil pengamatan setelah unitnya dibongkar, dan itu lebih akurat
  /// daripada yang tercatat saat unitnya diterima.
  void _pilihNota(ServiceOrderEntry n) {
    final brands = ref.read(brandsProvider).valueOrNull ?? const <Brand>[];

    setState(() {
      _nota = n;
      _nama.text = n.customerNama;
      _telp.text = n.customerTelp ?? '';
      if (_email.text.trim().isEmpty) _email.text = n.customerEmail ?? '';
      _snUnit.text = n.barangSn ?? '';
      if (_keluhan.text.trim().isEmpty) _keluhan.text = n.keluhan ?? '';
      _teknisiId = n.teknisiId ?? _teknisiId;
      // Tanggal masuk unitnya, bukan hari orang menyadarinya bergaransi.
      _tanggal = n.tanggalMasuk;
      _brandId ??= tebakBrand(
        brands,
        [n.barangNama, ?n.barangType].join(' '),
      )?.id;
    });
  }

  /// Melepas tautannya tanpa mengosongkan kolom. Yang dibatalkan adalah
  /// hubungannya ke nota itu, bukan data yang sudah terlanjur benar.
  void _lepasNota() => setState(() => _nota = null);

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _busy = true);

    final db = ref.read(databaseProvider);
    final claimId = widget.claim?.id ?? (_idBaru ??= _uuid.v4());

    final isi = {
      'tanggal': _tanggal.toUtc().toIso8601String(),
      'brand_id': _brandId!,
      'nama_pelanggan': _nama.text.trim(),
      'telp': _nullIfEmpty(_telp),
      'email': _nullIfEmpty(_email),
      'sn': _snUnit.text.trim(),
      'jenis': _jenis,
      'teknisi_id': _teknisiId,
      'keluhan': _nullIfEmpty(_keluhan),
      'no_perbaikan': _nullIfEmpty(_noPerbaikan),
      'status': _status,
      'catatan': _nullIfEmpty(_catatan),
    };

    try {
      if (widget.isNew) {
        await db.simpanClaim({...isi, 'id': claimId, 'created_by': user.id});
      } else {
        await db.ubahClaim(claimId, isi);
      }

      for (final id in _removedPartIds) {
        await db.hapusPart(id);
      }
      for (final p in _parts.where((e) => e.typeId != null)) {
        await db.simpanPart({
          'id': p.existingId ?? _uuid.v4(),
          'claim_id': claimId,
          'part_type_id': p.typeId!,
          'sn_bad_part': p.sn.text.trim().isEmpty ? null : p.sn.text.trim(),
        });
      }

      // Notanya ditandai bergaransi lewat fungsi khusus di server, bukan
      // update biasa: dua kolom itu tertutup bagi siapa pun selain admin,
      // dan layar ini juga dipakai teknisi.
      //
      // Paling akhir, karena server menolak tautan ke klaim yang belum
      // ada.
      if (_nota != null && widget.isNew) {
        await db.tautkanNotaKeKlaim(_nota!.id, claimId);
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          !widget.isNew
              ? 'Perubahan tersimpan'
              : _nota == null
              ? 'Klaim tersimpan'
              : 'Klaim tersimpan. Nota ${_nota!.noNota} sekarang '
                    'bertanda garansi.',
        ),
        duration: Duration(seconds: _nota == null ? 4 : 7),
      ),
    );
  }

  /// Simpan yang boleh disentuh teknisi pada klaim yang sudah ada: status,
  /// catatan, teknisi, dan part baru. Identitas unit dan pelanggan ditolak
  /// trigger di server, jadi sengaja tidak ikut dikirim -- kolom yang bisa
  /// diketik lalu ditolak diam-diam lebih buruk daripada yang terkunci.
  Future<void> _saveTeknisiScope() async {
    final c = widget.claim;
    if (c == null) return;
    setState(() => _busy = true);

    final db = ref.read(databaseProvider);
    try {
      await db.ubahClaim(c.id, {
        'teknisi_id': _teknisiId,
        'status': _status,
        'catatan': _nullIfEmpty(_catatan),
      });

      // Hanya baris part yang belum tersimpan. Mengubah atau menghapus
      // part yang sudah ada tetap milik admin (cp_update / cp_delete).
      for (final p in _parts.where(
        (e) => e.existingId == null && e.typeId != null,
      )) {
        await db.simpanPart({
          'id': _uuid.v4(),
          'claim_id': c.id,
          'part_type_id': p.typeId!,
          'sn_bad_part': p.sn.text.trim().isEmpty ? null : p.sn.text.trim(),
        });
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
        .showSnackBar(const SnackBar(content: Text('Perubahan tersimpan')));
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    final brands = ref.watch(brandsProvider).valueOrNull ?? const <Brand>[];
    final techs = ref.watch(pengerjaUntukProvider(_teknisiId));
    final types =
        ref.watch(partTypesProvider).valueOrNull ?? const <PartType>[];
    final allBrands =
        ref.watch(allBrandsProvider).valueOrNull ?? const <Brand>[];

    // Bawaannya diri sendiri, karena umumnya dialah yang menerima unit di
    // meja -- tetapi hanya kalau dirinya memang bisa ditunjuk. Admin tidak,
    // dan memaksakannya justru membuat kolom ini terisi nama yang salah.
    if (widget.isNew) {
      final aku = ref.read(currentUserProvider)?.id;
      if (aku != null && techs.any((p) => p.id == aku)) _teknisiId ??= aku;
    }

    final brandName = {for (final b in allBrands) b.id: b.nama}[_brandId];
    final size = MediaQuery.sizeOf(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Material(
          color: context.warna.permukaan,
          borderRadius: BorderRadius.circular(AppRadius.base),
          clipBehavior: Clip.antiAlias,
          child: Container(
            width: 1040,
            constraints: BoxConstraints(maxHeight: size.height - 80),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.base),
              border: Border.all(color: const Color(0xFFE4E7E7)),
            ),
            child: !_ready
                ? const SizedBox(
                    height: 240,
                    child: Center(
                      child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _header(brandName, isAdmin),
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
                                Expanded(child: _leftColumn(brands, isAdmin)),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: _rightColumn(techs, types, isAdmin),
                                ),
                              ],
                            ),
                          ),
                        ),
                        _footer(isAdmin),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------

  Widget _header(String? brandName, bool isAdmin) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.s,
        AppSpacing.s,
        AppSpacing.s,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.warna.teks, width: 1.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isNew
                      ? 'Klaim Baru'
                      : (_nama.text.isEmpty ? 'Klaim' : _nama.text),
                  style: Theme.of(context).textTheme.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    ?brandName,
                    _dateFmt.format(_tanggal),
                    if (_noPerbaikan.text.trim().isNotEmpty)
                      _noPerbaikan.text.trim(),
                  ].join('  ·  '),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          if (!widget.isNew) ...[
            StatusChip(_status),
            const SizedBox(width: AppSpacing.s),
          ],
          if (!isAdmin && !widget.isNew)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: Tooltip(
                message:
                    'Kamu bisa ubah status, catatan, teknisi, dan '
                    'tambah part. Data unit dan pelanggan diubah admin.',
                child: Icon(
                  Icons.lock_outline,
                  size: 15,
                  color: context.warna.teksLembut,
                ),
              ),
            ),
          IconButton(
            iconSize: 18,
            color: context.warna.teksLembut,
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _leftColumn(List<Brand> brands, bool isAdmin) {
    final editable = isAdmin || widget.isNew;

    final semuaNota =
        ref.watch(serviceOrdersProvider).valueOrNull ??
        const <ServiceOrderEntry>[];

    // Pada klaim baru bagian ini naik ke paling atas: dari nama
    // pelanggannya notanya dicari, dan begitu notanya terpilih kolom unit
    // di bawahnya ikut terisi sendiri. Pada klaim yang sudah ada ia tetap
    // di tempat semula -- tidak ada lagi yang perlu dicari di sana.
    final bagianPelanggan = <Widget>[
      const SectionLabel('Pelanggan'),
      const SizedBox(height: AppSpacing.s),
      if (widget.isNew)
        KolomNota(
          controller: _nama,
          focusNode: _namaFokus,
          nota: semuaNota,
          terpilih: _nota,
          onPilih: _pilihNota,
          onLepas: _lepasNota,
        )
      else
        LabeledField(
          label: 'Nama',
          required: true,
          child: TextFormField(
            controller: _nama,
            readOnly: !editable,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
          ),
        ),
      const SizedBox(height: AppSpacing.s),
      LabeledField(
        label: 'Telepon',
        child: TextFormField(
          controller: _telp,
          readOnly: !editable,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(hintText: '0812-3456-7890'),
        ),
      ),
      const SizedBox(height: AppSpacing.s),
      LabeledField(
        label: 'Email',
        // Wajib pada klaim baru: portal RMA sebagian brand menuntutnya.
        // Klaim lama yang disunting tidak dipaksa.
        required: widget.isNew,
        child: TextFormField(
          controller: _email,
          readOnly: !editable,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(hintText: 'nama@email.com'),
          validator: (v) => widget.isNew && (v ?? '').trim().isEmpty
              ? 'Email wajib untuk klaim garansi'
              : null,
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.isNew) ...[
          ...bagianPelanggan,
          const SizedBox(height: AppSpacing.sm),
        ],

        const SectionLabel('Unit'),
        const SizedBox(height: AppSpacing.s),

        // Ditanya paling dulu: jenisnya yang menentukan kolom mana di
        // bawahnya yang wajib diisi.
        LabeledField(
          label: 'Jenis Garansi',
          required: true,
          hint: ClaimJenis.hint(_jenis),
          child: DropdownButtonFormField<String>(
            initialValue: _jenis,
            isExpanded: true,
            onChanged: editable
                ? (v) => setState(() => _jenis = v ?? ClaimJenis.brand)
                : null,
            items: [
              for (final j in ClaimJenis.all)
                DropdownMenuItem(value: j, child: Text(ClaimJenis.label(j))),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: LabeledField(
                label: 'Brand',
                required: true,
                // Diisi pada kedua jenis. Pada garansi toko bukan untuk
                // ditagihkan, melainkan supaya merek unit yang sering
                // kembali tetap bisa dihitung.
                child: DropdownButtonFormField<int>(
                  initialValue: _brandId,
                  isExpanded: true,
                  hint: const Text('Pilih'),
                  onChanged: editable
                      ? (v) => setState(() => _brandId = v)
                      : null,
                  items: [
                    for (final b in brands)
                      DropdownMenuItem(value: b.id, child: Text(b.nama)),
                  ],
                  validator: (v) => v == null ? 'Wajib dipilih' : null,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: LabeledField(
                label: 'Tanggal Masuk',
                child: OutlinedButton(
                  onPressed: editable && !widget.isNew ? _pickDate : null,
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    side: const BorderSide(color: Color(0xFFCFD5D4), width: 1),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s,
                      vertical: 13,
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _dateFmt.format(_tanggal),
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
        LabeledField(
          label: 'Serial Number',
          required: ClaimJenis.perluSn(_jenis),
          hint: ClaimJenis.perluSn(_jenis)
              ? null
              : 'Boleh dikosongkan pada garansi toko.',
          child: TextFormField(
            controller: _snUnit,
            readOnly: !editable,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              suffixIcon: editable
                  ? ScanFieldButton(
                      onScanned: (v) => setState(() => _snUnit.text = v),
                    )
                  : null,
            ),
            validator: (v) =>
                ClaimJenis.perluSn(_jenis) && (v == null || v.trim().isEmpty)
                ? 'SN wajib untuk klaim ke brand'
                : null,
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        LabeledField(
          label: 'Keluhan',
          child: TextFormField(
            controller: _keluhan,
            readOnly: !editable,
            maxLines: 2,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(hintText: 'NO POWER, MATI TOTAL'),
          ),
        ),

        if (!widget.isNew) ...[
          const SizedBox(height: AppSpacing.sm),
          ...bagianPelanggan,
        ],
      ],
    );
  }

  Widget _rightColumn(List<Profile> techs, List<PartType> types, bool isAdmin) {
    final editable = isAdmin || widget.isNew;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Penanganan'),
        const SizedBox(height: AppSpacing.s),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: LabeledField(
                // Selalu bisa diubah, apa pun perannya. Ini kolom yang
                // memindahkan pekerjaan dari satu teknisi ke teknisi lain.
                label: 'Teknisi',
                hint: techs.isEmpty
                    ? 'Belum ada teknisi. Tambahkan di Pengaturan → Pengguna.'
                    : null,
                child: DropdownButtonFormField<String>(
                  initialValue: _teknisiId,
                  isExpanded: true,
                  onChanged: (v) => setState(() => _teknisiId = v),
                  items: [
                    for (final t in techs)
                      DropdownMenuItem(value: t.id, child: Text(t.nama)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: LabeledField(
                // Selalu bisa diubah, apa pun perannya: teknisi menutup
                // pekerjaannya sendiri dari sini, dan klaim tanpa nota
                // tidak punya jalur lain.
                label: 'Status',
                child: DropdownButtonFormField<String>(
                  initialValue: _status,
                  isExpanded: true,
                  onChanged: (v) => setState(() => _status = v!),
                  items: [
                    for (final s in ClaimStatus.all)
                      DropdownMenuItem(
                        value: s,
                        child: Text(ClaimStatus.label(s)),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s),
        LabeledField(
          label: 'No Perbaikan / RMA',
          child: TextFormField(
            controller: _noPerbaikan,
            readOnly: !editable,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'IDD7R20024'),
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        LabeledField(
          // Catatan teknisi -- dibuka untuk semua peran.
          label: 'Catatan',
          child: TextFormField(controller: _catatan, maxLines: 2),
        ),

        const SizedBox(height: AppSpacing.sm),
        SectionLabel(
          // Menambah part terbuka untuk teknisi (server: cp_insert).
          // Mengubah atau menghapus part yang sudah tersimpan tetap milik
          // admin -- baris itu dikunci di bawah.
          'Part yang Diklaim',
          trailing: InlineAction(
            label: 'Tambah',
            onTap: () => setState(() => _parts.add(_PartEntry())),
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        // Baris yang belum tersimpan boleh disunting siapa pun yang
        // menambahnya; yang sudah ada hanya admin (cp_update / cp_delete).
        for (var i = 0; i < _parts.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              children: [
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<int>(
                    initialValue: _parts[i].typeId,
                    isExpanded: true,
                    hint: const Text('Part'),
                    onChanged: (editable || _parts[i].existingId == null)
                        ? (v) => setState(() => _parts[i].typeId = v)
                        : null,
                    // Namanya yang dibaca, kodenya yang dicocokkan. Kode
                    // saja tidak cukup untuk memilih -- ADPT baru berarti
                    // sesuatu setelah dibaca sebagai Adaptor -- jadi nama
                    // naik jadi baris utama dan kodenya turun jadi
                    // keterangan kecil.
                    selectedItemBuilder: (context) => [
                      for (final t in types)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            t.nama,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    items: [
                      for (final t in types)
                        DropdownMenuItem(value: t.id, child: PilihanPart(t)),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: TextFormField(
                    controller: _parts[i].sn,
                    readOnly: !(editable || _parts[i].existingId == null),
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'SN bad part',
                      suffixIcon: (editable || _parts[i].existingId == null)
                          ? ScanFieldButton(
                              title: 'Pindai SN Bad Part',
                              onScanned: (v) =>
                                  setState(() => _parts[i].sn.text = v),
                            )
                          : null,
                    ),
                  ),
                ),
                if (editable || _parts[i].existingId == null)
                  IconButton(
                    iconSize: 16,
                    color: context.warna.bahaya,
                    icon: const Icon(Icons.close),
                    onPressed: () => _removePart(i),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _footer(bool isAdmin) {
    final c = widget.claim;
    final editable = isAdmin || widget.isNew;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.s,
        AppSpacing.sm,
        AppSpacing.s,
      ),
      decoration: BoxDecoration(
        color: context.warna.teredam,
        border: const Border(top: BorderSide(color: Color(0xFFE4E7E7))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              c == null
                  ? 'Tanggal terisi otomatis saat disimpan.'
                  : 'Diubah terakhir ${_stampFmt.format(c.updatedAt)}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: const Text('BATAL'),
          ),
          const SizedBox(width: AppSpacing.xs),
          FilledButton(
            onPressed: _busy ? null : (editable ? _save : _saveTeknisiScope),
            child: _busy
                ? SizedBox(
                    height: 14,
                    width: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.warna.permukaan,
                    ),
                  )
                : Text(widget.isNew ? 'SIMPAN KLAIM' : 'SIMPAN PERUBAHAN'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tanggal,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    setState(() {
      _tanggal = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _tanggal.hour,
        _tanggal.minute,
      );
    });
  }

  void _removePart(int i) {
    setState(() {
      final removed = _parts.removeAt(i);
      if (removed.existingId != null) _removedPartIds.add(removed.existingId!);
      removed.dispose();
      if (_parts.isEmpty) _parts.add(_PartEntry());
    });
  }
}
