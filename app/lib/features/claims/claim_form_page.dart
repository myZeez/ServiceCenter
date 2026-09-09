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
final _dateFmt = DateFormat('dd MMMM yyyy');

/// Satu baris part yang diklaim, beserta SN part rusaknya.
class _PartEntry {
  _PartEntry({this.existingId, this.partTypeId, String? sn})
    : snController = TextEditingController(text: sn ?? '');

  /// Terisi bila baris ini sudah tersimpan sebelumnya.
  final String? existingId;
  int? partTypeId;
  final TextEditingController snController;

  void dispose() => snController.dispose();
}

/// Formulir klaim. Tanpa argumen berarti membuat baru; dengan [claim]
/// berarti menyunting -- dan penyuntingan penuh hanya dibuka untuk admin.
class ClaimFormPage extends ConsumerStatefulWidget {
  const ClaimFormPage({super.key, this.claim});

  final Claim? claim;

  bool get isEdit => claim != null;

  @override
  ConsumerState<ClaimFormPage> createState() => _ClaimFormPageState();
}

class _ClaimFormPageState extends ConsumerState<ClaimFormPage> {
  final _formKey = GlobalKey<FormState>();

  final _nama = TextEditingController();
  final _telp = TextEditingController();
  final _email = TextEditingController();
  final _sn = TextEditingController();
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
  ///
  /// Terisi ketika unit ini sudah lebih dulu masuk sebagai servis biasa --
  /// keadaan yang justru paling sering: yang menemukan unitnya bergaransi
  /// adalah teknisi yang sudah membongkarnya, bukan meja depan.
  ServiceOrderEntry? _nota;

  /// Id klaim baru, dibuat sekali. Kalau dibuat ulang tiap kali tombol
  /// simpan ditekan, percobaan kedua atas penyimpanan yang gagal separuh
  /// jalan akan menerbitkan klaim kembar alih-alih melanjutkan yang tadi.
  String? _idBaru;

  List<_PartEntry> _parts = [];

  /// Part yang dibuang di layar tapi belum dihapus dari basis data.
  final List<String> _removedPartIds = [];

  bool _busy = false;
  bool _partsLoaded = false;

  @override
  void initState() {
    super.initState();

    final c = widget.claim;
    if (c == null) {
      _tanggal = DateTime.now();
      _parts = [_PartEntry()];
      _partsLoaded = true;
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
    _sn.text = c.sn;
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
                  partTypeId: r.partTypeId,
                  sn: r.snBadPart,
                ),
            ];
      _partsLoaded = true;
    });
  }

  @override
  void dispose() {
    _nama.dispose();
    _telp.dispose();
    _email.dispose();
    _sn.dispose();
    _keluhan.dispose();
    _noPerbaikan.dispose();
    _catatan.dispose();
    _namaFokus.dispose();
    for (final p in _parts) {
      p.dispose();
    }
    super.dispose();
  }

  /// Mengambil alih isi formulir dari sebuah nota servis.
  ///
  /// Yang sudah diketik tidak ditimpa begitu saja pada kolom yang sifatnya
  /// pengamatan teknisi -- keluhan bisa saja sudah dilengkapi setelah
  /// unitnya dibongkar, dan itu lebih akurat daripada yang tercatat di
  /// meja depan. Identitas unitnya sendiri diambil dari nota, karena di
  /// situlah kebenarannya.
  void _pilihNota(ServiceOrderEntry n) {
    final brands = ref.read(brandsProvider).valueOrNull ?? const <Brand>[];

    setState(() {
      _nota = n;
      _nama.text = n.customerNama;
      _telp.text = n.customerTelp ?? '';
      if (_email.text.trim().isEmpty) _email.text = n.customerEmail ?? '';
      _sn.text = n.barangSn ?? '';
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tanggal,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    setState(() {
      // Jam aslinya dipertahankan; yang dikoreksi biasanya tanggalnya.
      _tanggal = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _tanggal.hour,
        _tanggal.minute,
      );
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _busy = true);

    final db = ref.read(databaseProvider);
    final claimId = widget.claim?.id ?? (_idBaru ??= _uuid.v4());

    String? nullIfEmpty(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();

    final isi = {
      // Jam lokal saat diinput, bukan saat baris ini sampai di server.
      'tanggal': _tanggal.toUtc().toIso8601String(),
      'brand_id': _brandId!,
      'nama_pelanggan': _nama.text.trim(),
      'telp': nullIfEmpty(_telp),
      'email': nullIfEmpty(_email),
      'sn': _sn.text.trim(),
      'jenis': _jenis,
      'teknisi_id': _teknisiId,
      'keluhan': nullIfEmpty(_keluhan),
      'no_perbaikan': nullIfEmpty(_noPerbaikan),
      'status': _status,
      'catatan': nullIfEmpty(_catatan),
    };

    try {
      if (widget.isEdit) {
        await db.ubahClaim(claimId, isi);
      } else {
        await db.simpanClaim({...isi, 'id': claimId, 'created_by': user.id});
      }

      for (final id in _removedPartIds) {
        await db.hapusPart(id);
      }

      for (final p in _parts.where((e) => e.partTypeId != null)) {
        await db.simpanPart({
          'id': p.existingId ?? _uuid.v4(),
          'claim_id': claimId,
          'part_type_id': p.partTypeId!,
          'sn_bad_part': p.snController.text.trim().isEmpty
              ? null
              : p.snController.text.trim(),
        });
      }

      // Notanya ditandai bergaransi dari sini, lewat satu fungsi khusus
      // di server: penjaga kolom menutup garansi dan claim_id bagi update
      // biasa dari teknisi, dan justru teknisilah yang berdiri di sini.
      //
      // Dijalankan paling akhir supaya klaimnya sudah pasti ada -- server
      // menolak tautan ke baris yang belum ada.
      if (_nota != null && !widget.isEdit) {
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
          widget.isEdit
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

  void _removePart(int i) {
    setState(() {
      final removed = _parts.removeAt(i);
      if (removed.existingId != null) _removedPartIds.add(removed.existingId!);
      removed.dispose();
      if (_parts.isEmpty) _parts.add(_PartEntry());
    });
  }

  @override
  Widget build(BuildContext context) {
    final brands = ref.watch(brandsProvider).valueOrNull ?? const <Brand>[];
    final techs = ref.watch(pengerjaUntukProvider(_teknisiId));
    final partTypes =
        ref.watch(partTypesProvider).valueOrNull ?? const <PartType>[];

    // Default teknisi = yang sedang login, karena umumnya dialah yang
    // menerima unit di meja -- tetapi hanya kalau dirinya memang bisa
    // ditunjuk. Admin tidak, dan memaksakannya justru membuat kolom ini
    // terisi nama yang salah.
    if (!widget.isEdit) {
      final aku = ref.read(currentUserProvider)?.id;
      if (aku != null && techs.any((p) => p.id == aku)) _teknisiId ??= aku;
    }

    if (!_partsLoaded) {
      return const Scaffold(
        body: Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final semuaNota =
        ref.watch(serviceOrdersProvider).valueOrNull ??
        const <ServiceOrderEntry>[];

    // Dirakit sebagai daftar tersendiri karena letaknya berpindah: pada
    // klaim baru bagian ini naik ke paling atas, sebab dari namanyalah
    // notanya dicari. Pada klaim yang sedang disunting ia tetap di
    // tempatnya semula -- di sana tidak ada yang perlu dicari lagi.
    final bagianPelanggan = <Widget>[
      const SectionLabel('Pelanggan'),
      const SizedBox(height: AppSpacing.s),
      if (widget.isEdit)
        LabeledField(
          label: 'Nama',
          required: true,
          child: TextFormField(
            controller: _nama,
            textCapitalization: TextCapitalization.characters,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
          ),
        )
      else
        KolomNota(
          controller: _nama,
          focusNode: _namaFokus,
          nota: semuaNota,
          terpilih: _nota,
          onPilih: _pilihNota,
          onLepas: _lepasNota,
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
      const SizedBox(height: AppSpacing.s),
      LabeledField(
        label: 'Email',
        // Wajib pada klaim baru: portal RMA beberapa brand menuntutnya
        // saat unit didaftarkan. Klaim lama yang disunting tidak dipaksa
        // -- kolomnya memang belum ada saat itu dicatat.
        required: !widget.isEdit,
        child: TextFormField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(hintText: 'nama@email.com'),
          validator: (v) => !widget.isEdit && (v ?? '').trim().isEmpty
              ? 'Email wajib untuk klaim garansi'
              : null,
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.sm,
        title: Text(widget.isEdit ? 'Ubah Klaim' : 'Klaim Baru'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.s,
            AppSpacing.sm,
            AppSpacing.md,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!widget.isEdit) ...[
                      ...bagianPelanggan,
                      const SizedBox(height: AppSpacing.md),
                    ],

                    const SectionLabel('Unit'),
                    const SizedBox(height: AppSpacing.s),

                    // Tanggal hanya bisa dikoreksi saat menyunting. Pada
                    // klaim baru ia terisi otomatis dan tidak boleh diutak-atik.
                    if (widget.isEdit) ...[
                      LabeledField(
                        label: 'Tanggal Masuk',
                        child: OutlinedButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(_dateFmt.format(_tanggal)),
                          ),
                          style: OutlinedButton.styleFrom(
                            alignment: Alignment.centerLeft,
                            side: const BorderSide(
                              color: Color(0xFFCFD5D4),
                              width: 1,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.s,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s),
                    ],

                    // Jenisnya ditanya paling dulu: ia yang menentukan
                    // kolom mana di bawahnya yang wajib.
                    LabeledField(
                      label: 'Jenis Garansi',
                      required: true,
                      hint: ClaimJenis.hint(_jenis),
                      child: DropdownButtonFormField<String>(
                        initialValue: _jenis,
                        isExpanded: true,
                        items: [
                          for (final j in ClaimJenis.all)
                            DropdownMenuItem(
                              value: j,
                              child: Text(ClaimJenis.label(j)),
                            ),
                        ],
                        onChanged: (v) =>
                            setState(() => _jenis = v ?? ClaimJenis.brand),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s),

                    LabeledField(
                      label: 'Brand',
                      required: true,
                      // Diisi pada kedua jenis. Pada garansi toko bukan
                      // untuk ditagihkan, melainkan supaya merek unit yang
                      // sering kembali tetap bisa dihitung.
                      hint: ClaimJenis.ditagihkan(_jenis)
                          ? null
                          : 'Tidak ditagihkan ke brand — hanya untuk '
                                'mencatat merek unitnya.',
                      child: DropdownButtonFormField<int>(
                        initialValue: _brandId,
                        isExpanded: true,
                        hint: const Text('Pilih brand'),
                        items: [
                          for (final b in brands)
                            DropdownMenuItem(value: b.id, child: Text(b.nama)),
                        ],
                        onChanged: (v) => setState(() => _brandId = v),
                        validator: (v) =>
                            v == null ? 'Brand wajib dipilih' : null,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s),
                    LabeledField(
                      label: 'Serial Number',
                      required: ClaimJenis.perluSn(_jenis),
                      hint: !ClaimJenis.perluSn(_jenis)
                          ? 'Boleh dikosongkan pada garansi toko.'
                          : scanSupported
                          ? 'Pindai barcode untuk menghindari salah ketik.'
                          : null,
                      child: TextFormField(
                        controller: _sn,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          suffixIcon: ScanFieldButton(
                            onScanned: (v) => setState(() => _sn.text = v),
                          ),
                        ),
                        validator: (v) =>
                            ClaimJenis.perluSn(_jenis) &&
                                (v == null || v.trim().isEmpty)
                            ? 'SN wajib untuk klaim ke brand'
                            : null,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s),
                    LabeledField(
                      label: 'Keluhan',
                      child: TextFormField(
                        controller: _keluhan,
                        textCapitalization: TextCapitalization.characters,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          hintText: 'NO POWER, LCD ABNORMAL LINE',
                        ),
                      ),
                    ),

                    if (widget.isEdit) ...[
                      const SizedBox(height: AppSpacing.md),
                      ...bagianPelanggan,
                    ],

                    const SizedBox(height: AppSpacing.md),
                    SectionLabel(
                      'Part yang Diklaim',
                      trailing: InlineAction(
                        label: 'Tambah',
                        onTap: () => setState(() => _parts.add(_PartEntry())),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s),

                    for (var i = 0; i < _parts.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.s),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              flex: 2,
                              child: LabeledField(
                                label: 'Part',
                                child: DropdownButtonFormField<int>(
                                  initialValue: _parts[i].partTypeId,
                                  isExpanded: true,
                                  hint: const Text('—'),
                                  // Namanya yang dibaca, kodenya yang
                                  // dicocokkan. Kode saja tidak cukup untuk
                                  // memilih -- ADPT baru berarti sesuatu
                                  // setelah dibaca sebagai Adaptor -- jadi
                                  // nama naik jadi baris utama dan kodenya
                                  // turun jadi keterangan kecil.
                                  selectedItemBuilder: (context) => [
                                    for (final p in partTypes)
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          p.nama,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                  items: [
                                    for (final p in partTypes)
                                      DropdownMenuItem(
                                        value: p.id,
                                        child: PilihanPart(p),
                                      ),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _parts[i].partTypeId = v),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              flex: 3,
                              child: LabeledField(
                                label: 'SN Bad Part',
                                child: TextFormField(
                                  controller: _parts[i].snController,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  decoration: InputDecoration(
                                    suffixIcon: ScanFieldButton(
                                      title: 'Pindai SN Bad Part',
                                      onScanned: (v) => setState(
                                        () => _parts[i].snController.text = v,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              iconSize: 18,
                              color: context.warna.bahaya,
                              icon: const Icon(Icons.close),
                              onPressed: () => _removePart(i),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: AppSpacing.sm),
                    const SectionLabel('Penanganan'),
                    const SizedBox(height: AppSpacing.s),

                    LabeledField(
                      label: 'Teknisi',
                      hint: techs.isEmpty
                          ? 'Belum ada teknisi. Tambahkan di Pengaturan → '
                                'Pengguna.'
                          : null,
                      child: DropdownButtonFormField<String>(
                        initialValue: _teknisiId,
                        isExpanded: true,
                        items: [
                          for (final t in techs)
                            DropdownMenuItem(value: t.id, child: Text(t.nama)),
                        ],
                        onChanged: (v) => setState(() => _teknisiId = v),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s),
                    LabeledField(
                      label: 'Status',
                      child: DropdownButtonFormField<String>(
                        initialValue: _status,
                        isExpanded: true,
                        items: [
                          for (final s in ClaimStatus.all)
                            DropdownMenuItem(
                              value: s,
                              child: Text(ClaimStatus.label(s)),
                            ),
                        ],
                        onChanged: (v) => setState(() => _status = v!),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s),
                    LabeledField(
                      label: 'No Perbaikan / RMA',
                      child: TextFormField(
                        controller: _noPerbaikan,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          hintText: 'IDD7R20024',
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s),
                    LabeledField(
                      label: 'Catatan',
                      child: TextFormField(controller: _catatan, maxLines: 3),
                    ),

                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      onPressed: _busy ? null : _save,
                      child: Text(
                        widget.isEdit ? 'SIMPAN PERUBAHAN' : 'SIMPAN KLAIM',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s),
                    Text(
                      widget.isEdit
                          ? 'Perubahan langsung tersimpan ke server dan '
                                'terlihat di perangkat lain.'
                          : 'Tanggal terisi otomatis. Data langsung tersimpan '
                                'ke server dan terlihat di perangkat lain.',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
