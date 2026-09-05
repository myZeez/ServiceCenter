import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/data/galat.dart';
import '../../core/data/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/swiss_widgets.dart';
import '../scan/scan_page.dart';
import '../service/customer_field.dart';
import 'hitung_harga.dart';
import 'part_status.dart';

const _uuid = Uuid();

final _rp = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp',
  decimalDigits: 0,
);
final _persen = NumberFormat('#,##0.#', 'id_ID');

Future<void> showPartDialog(BuildContext context, {PartOrder? pesanan}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Tutup',
    barrierColor: const Color(0x33000000),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, _, _) => PartDialog(pesanan: pesanan),
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

class PartDialog extends ConsumerStatefulWidget {
  const PartDialog({super.key, this.pesanan});

  final PartOrder? pesanan;

  bool get isNew => pesanan == null;

  @override
  ConsumerState<PartDialog> createState() => _PartDialogState();
}

class _PartDialogState extends ConsumerState<PartDialog> {
  final _formKey = GlobalKey<FormState>();

  final _nama = TextEditingController();
  final _telp = TextEditingController();
  final _type = TextEditingController();
  final _sn = TextEditingController();
  final _partReq = TextEditingController();
  final _hpp = TextEditingController();
  final _harga = TextEditingController();
  final _dp = TextEditingController();
  final _catatan = TextEditingController();

  final _namaFokus = FocusNode();
  final _dpFokus = FocusNode();

  CustomerEntry? _pelanggan;

  String? _keterangan;
  String? _teknisiId;
  String? _stok;
  String? _notaId;
  String _tahap = PartTahap.tanya;

  /// Persentase yang dipilih dari daftar. Null berarti admin mengetik
  /// sendiri harga jualnya, dan persentasenya dibaca mundur dari situ.
  double? _up;

  bool _busy = false;
  String? _error;

  /// Modal sudah pernah dibaca dari server untuk pesanan yang disunting.
  /// Dipakai sekali saja: kalau tidak, tiap kali aliran datanya berdenyut
  /// isian yang sedang diketik akan tertimpa nilai lama.
  bool _modalTerbaca = false;

  /// Persentase bawaan sudah dipasang untuk baris baru. Sekali saja, atau
  /// pilihan yang baru saja diubah admin akan dikembalikan sendiri tiap
  /// kali layarnya dilukis ulang.
  bool _bawaanDipakai = false;

  @override
  void initState() {
    super.initState();
    _harga.addListener(_hargaBerubah);

    final p = widget.pesanan;
    if (p == null) return;

    _nama.text = p.customerNama;
    _telp.text = p.customerTelp ?? '';
    _type.text = p.barangType ?? '';
    _sn.text = p.barangSn ?? '';
    _partReq.text = p.partReq;
    _harga.text = p.harga == null ? '' : p.harga!.toInt().toString();
    _dp.text = p.dp == 0 ? '' : p.dp.toInt().toString();
    _catatan.text = p.catatan ?? '';
    _keterangan = p.keterangan;
    _teknisiId = p.teknisiId;
    _stok = p.stok;
    _tahap = p.tahap;
    _notaId = p.serviceOrderId;
  }

  @override
  void dispose() {
    _harga.removeListener(_hargaBerubah);
    for (final c in [
      _nama,
      _telp,
      _type,
      _sn,
      _partReq,
      _hpp,
      _harga,
      _dp,
      _catatan,
    ]) {
      c.dispose();
    }
    _namaFokus.dispose();
    _dpFokus.dispose();
    super.dispose();
  }

  void _hargaBerubah() => setState(() {});

  String? _kosongNull(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  double? _angka(TextEditingController c) =>
      c.text.trim().isEmpty ? null : double.tryParse(c.text.trim());

  /// Harga jual dihitung ulang tiap kali modal atau persentasenya berubah.
  ///
  /// Hanya saat persentasenya memang dipilih dari daftar. Begitu admin
  /// mengetik sendiri angkanya, hitungan berhenti mengambil alih kolom
  /// itu -- pembulatan ke angka yang enak disebut adalah keputusan orang,
  /// bukan kesalahan yang perlu dibetulkan.
  void _hitungUlang() {
    final hpp = _angka(_hpp);
    if (hpp == null || _up == null) return;
    _harga.text = hargaJual(hpp, _up!).round().toString();
  }

  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) return;

    final harga = _angka(_harga);
    final dp = _angka(_dp) ?? 0;

    // Dua aturan yang juga ditegakkan Postgres. Diperiksa di sini juga
    // supaya penolakannya berupa kalimat di tempat yang salah, bukan
    // galat constraint yang tidak bisa dibaca siapa pun.
    if (_tahap != PartTahap.tanya && _tahap != PartTahap.batal &&
        harga == null) {
      setState(() => _error = 'Isi harga jualnya dulu sebelum pesanan '
          'berjalan. Pelanggan perlu angka untuk dipegang.');
      return;
    }
    if (dp > 0 && harga == null) {
      setState(() => _error = 'DP tidak bisa dicatat tanpa harga: sisanya '
          'jadi tidak terhitung.');
      return;
    }

    // Menutup pesanan berarti menyatakan uangnya sudah masuk penuh.
    // Menutupnya sementara sisanya masih ada adalah cara paling mudah
    // kehilangan tagihan: barisnya keluar dari daftar yang diperiksa
    // tiap hari, dan tidak ada apa pun yang mengingatkannya lagi.
    if (_tahap == PartTahap.selesai &&
        harga != null &&
        sisaTagihan(harga, dp) > 0) {
      setState(() => _error =
          'Sisa tagihan masih ${_rp.format(sisaTagihan(harga, dp))}. '
          'Genapkan DP-nya, atau turunkan harga kalau memang diberi '
          'potongan.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final client = ref.read(supabaseProvider);
    final db = ref.read(databaseProvider);
    final user = ref.read(currentUserProvider);

    try {
      // Pelanggan baru dibuatkan catatannya sendiri, sama seperti di nota
      // servis, supaya kunjungan berikutnya tinggal dipilih.
      var customerId = _pelanggan?.id;
      if (customerId == null) {
        final baru = await client
            .from('customers')
            .insert({'nama': _nama.text.trim(), 'telp': _kosongNull(_telp)})
            .select()
            .single();
        customerId = baru['id'] as String;
      }

      final id = widget.pesanan?.id ?? _uuid.v4();

      await db.simpanPartOrder({
        'id': id,
        'customer_nama': _nama.text.trim(),
        'customer_telp': _kosongNull(_telp),
        'customer_id': customerId,
        'barang_type': _kosongNull(_type),
        'barang_sn': _kosongNull(_sn),
        'part_req': _partReq.text.trim(),
        'keterangan': _keterangan,
        'teknisi_id': _teknisiId,
        'stok': _stok,
        'tahap': _tahap,
        'harga': harga,
        'dp': dp,
        'service_order_id': _notaId,
        'catatan': _kosongNull(_catatan),
        if (widget.isNew) 'created_by': user!.id,
      });

      // Modal disimpan terpisah, dan hanya kalau ada isinya. Baris kosong
      // di tabel rahasia tidak menambah apa pun selain baris kosong.
      final hpp = _angka(_hpp);
      if (hpp != null || _up != null) {
        await db.simpanPartCost({
          'part_order_id': id,
          'hpp': hpp,
          'up_persen': _up,
        });
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isNew ? 'Tanya harga tersimpan' : 'Pesanan diperbarui',
          ),
        ),
      );
    } on PostgrestException catch (e) {
      setState(() => _error = pesanGalat(e));
    } catch (e) {
      setState(() => _error = pesanGalat(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    // Tautan pelanggan dan modal sama-sama datang belakangan dari server;
    // keduanya diambil sekali saja, saat daftarnya sudah ada.
    final idTertaut = widget.pesanan?.customerId;
    if (_pelanggan == null && idTertaut != null) {
      for (final c in ref.watch(customersProvider).valueOrNull ??
          const <CustomerEntry>[]) {
        if (c.id == idTertaut) {
          _pelanggan = c;
          break;
        }
      }
    }

    // Baris baru dimulai dengan persentase yang biasa dipakai toko, supaya
    // harga jualnya langsung muncul begitu modalnya diketik.
    if (widget.isNew && !_bawaanDipakai) {
      final s = ref.watch(partSettingsProvider).valueOrNull;
      if (s != null) {
        _bawaanDipakai = true;
        if (s.upTokoPilihan.contains(s.upTokoBawaan)) _up = s.upTokoBawaan;
      }
    }

    if (!_modalTerbaca && widget.pesanan != null) {
      final biaya = ref.watch(partCostProvider(widget.pesanan!.id));
      if (biaya != null) {
        _modalTerbaca = true;
        _hpp.text = biaya.hpp == null ? '' : biaya.hpp!.toInt().toString();
        _up = biaya.upPersen;
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
            width: 940,
            constraints: BoxConstraints(maxHeight: size.height - 80),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.base),
              border: Border.all(color: const Color(0xFFE4E7E7)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _kepala(context),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Form(key: _formKey, child: _isi(context)),
                  ),
                ),
                _kaki(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _kepala(BuildContext context) {
    final p = widget.pesanan;

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
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.isNew ? 'TANYA HARGA' : 'UBAH PESANAN',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  widget.isNew
                      ? 'Dicatat sekarang, harganya menyusul setelah '
                            'partnya ketemu.'
                      : 'Dibuat ${DateFormat('dd MMM yyyy').format(p!.tanggal)}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          if (!widget.isNew) PartTahapChip(_tahap),
          const SizedBox(width: AppSpacing.xs),
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

  Widget _isi(BuildContext context) {
    final pelanggan =
        ref.watch(customersProvider).valueOrNull ?? const <CustomerEntry>[];
    final techs = ref.watch(pengerjaUntukProvider(_teknisiId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Pelanggan dan Unit'),
        const SizedBox(height: AppSpacing.s),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: CustomerField(
                controller: _nama,
                focusNode: _namaFokus,
                pelanggan: pelanggan,
                terpilih: _pelanggan,
                onPilih: (c) => setState(() {
                  _pelanggan = c;
                  _nama.text = c.nama;
                  if (_telp.text.trim().isEmpty) _telp.text = c.telp ?? '';
                }),
                onBaru: () => setState(() => _pelanggan = null),
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: LabeledField(
                label: 'Telepon',
                child: TextFormField(
                  controller: _telp,
                  keyboardType: TextInputType.phone,
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
                label: 'Tipe',
                child: TextFormField(
                  controller: _type,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(hintText: 'ASUS X441BA'),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: LabeledField(
                label: 'SN',
                child: TextFormField(
                  controller: _sn,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    suffixIcon: ScanFieldButton(
                      title: 'Pindai SN unit',
                      onScanned: (v) => setState(() => _sn.text = v),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.sm),
        const SectionLabel('Part yang Dicari'),
        const SizedBox(height: AppSpacing.s),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: LabeledField(
                label: 'Part Req',
                required: true,
                child: TextFormField(
                  controller: _partReq,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    hintText: 'KEYBOARD, LCD 14 SLIM 30 PIN',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Part yang dicari wajib diisi'
                      : null,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: LabeledField(
                label: 'Keterangan',
                child: DropdownButtonFormField<String>(
                  initialValue: _keterangan,
                  isExpanded: true,
                  hint: const Text('—'),
                  items: const [
                    DropdownMenuItem(value: 'oem', child: Text('OEM')),
                    DropdownMenuItem(value: 'ori', child: Text('ORI')),
                    DropdownMenuItem(value: 'copy', child: Text('Copy')),
                  ],
                  onChanged: (v) => setState(() => _keterangan = v),
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
                label: 'Teknisi',
                hint: techs.isEmpty ? 'Belum ada teknisi terdaftar.' : null,
                child: DropdownButtonFormField<String>(
                  initialValue: _teknisiId,
                  isExpanded: true,
                  hint: const Text('Belum ditentukan'),
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
                label: 'Stok',
                child: DropdownButtonFormField<String>(
                  initialValue: _stok,
                  isExpanded: true,
                  hint: const Text('Belum dicek'),
                  items: [
                    for (final s in PartStok.all)
                      DropdownMenuItem(
                        value: s,
                        child: Text(PartStok.label(s)),
                      ),
                  ],
                  onChanged: (v) => setState(() => _stok = v),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.sm),
        const SectionLabel('Harga'),
        const SizedBox(height: AppSpacing.s),
        _harganya(context),

        const SizedBox(height: AppSpacing.sm),
        const SectionLabel('Pesanan'),
        const SizedBox(height: AppSpacing.s),
        _pesanannya(context),

        const SizedBox(height: AppSpacing.s),
        LabeledField(
          label: 'Catatan',
          child: TextFormField(controller: _catatan, maxLines: 2),
        ),
      ],
    );
  }

  Widget _harganya(BuildContext context) {
    final pilihan = ref.watch(upTokoPilihanProvider);
    final hpp = _angka(_hpp);
    final harga = _angka(_harga);

    // Persentase yang benar-benar berlaku, dibaca dari harga yang tertulis
    // sekarang. Berbeda dari yang dipilih di dropdown begitu angkanya
    // dibulatkan, dan justru selisih itulah yang perlu terlihat.
    final upNyata = (hpp != null && harga != null)
        ? upPersenDari(hpp, harga)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: LabeledField(
                label: 'HPP (Modal)',
                hint: 'Tidak terlihat oleh teknisi.',
                child: TextFormField(
                  controller: _hpp,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(prefixText: 'Rp '),
                  onChanged: (_) => setState(_hitungUlang),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: LabeledField(
                label: 'Up Toko',
                hint: 'Diatur di Pengaturan.',
                child: DropdownButtonFormField<double>(
                  initialValue: pilihan.contains(_up) ? _up : null,
                  isExpanded: true,
                  hint: const Text('Ketik harga sendiri'),
                  items: [
                    for (final p in pilihan)
                      DropdownMenuItem(
                        value: p,
                        child: Text('${_persen.format(p)}%'),
                      ),
                  ],
                  onChanged: (v) => setState(() {
                    _up = v;
                    _hitungUlang();
                  }),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: LabeledField(
                label: 'Harga Jual',
                child: TextFormField(
                  controller: _harga,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(prefixText: 'Rp '),
                ),
              ),
            ),
          ],
        ),
        if (hpp != null && harga != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: const BoxDecoration(
              color: AppColors.lightGrey,
              border: Border(left: BorderSide(color: AppColors.black, width: 3)),
            ),
            child: Text(
              'Untung ${_rp.format(margin(hpp, harga))}'
              '${upNyata == null ? '' : '  ·  ${_persen.format(upNyata)}% '
                  'dari modal'}',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.black,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _pesanannya(BuildContext context) {
    final harga = _angka(_harga);
    final dp = _angka(_dp) ?? 0;
    final belumAdaHarga = harga == null;

    // Nota servis milik pelanggan ini saja. Daftar seluruh nota toko tidak
    // bisa dipakai memilih apa pun begitu jumlahnya lewat seratus.
    final notaPelanggan = [
      for (final n in ref.watch(serviceOrdersProvider).valueOrNull ??
          const <ServiceOrderEntry>[])
        if (n.customerId != null && n.customerId == _pelanggan?.id) n,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tombol yang memulai pemesanan. Sengaja satu tindakan menonjol,
        // bukan sekadar mengganti nilai dropdown: membayar DP adalah saat
        // uang pelanggan mulai dipegang toko, dan itu pantas terasa seperti
        // keputusan.
        if (_tahap == PartTahap.tanya) ...[
          Row(
            children: [
              FilledButton.icon(
                onPressed: belumAdaHarga
                    ? null
                    : () => setState(() {
                        _tahap = PartTahap.dipesan;
                        _dpFokus.requestFocus();
                      }),
                icon: const Icon(Icons.payments_outlined, size: 18),
                label: const Text('USER DP'),
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: Text(
                  belumAdaHarga
                      ? 'Isi harga jualnya dulu — DP tanpa harga membuat '
                            'sisa tagihannya tidak bisa dihitung.'
                      : 'Pelanggan jadi memesan? Tekan ini, lalu isi DP-nya.',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s),
        ],

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: LabeledField(
                label: 'Tahap',
                child: DropdownButtonFormField<String>(
                  initialValue: _tahap,
                  isExpanded: true,
                  items: [
                    for (final t in PartTahap.all)
                      DropdownMenuItem(
                        value: t,
                        child: Text(PartTahap.label(t)),
                      ),
                  ],
                  onChanged: (v) => setState(() => _tahap = v!),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: LabeledField(
                label: 'DP User',
                child: TextFormField(
                  controller: _dp,
                  focusNode: _dpFokus,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(prefixText: 'Rp '),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: LabeledField(
                label: 'Sisa Tagihan',
                child: Container(
                  height: 48,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.lightGrey,
                    border: Border.all(color: const Color(0xFFCFD5D4)),
                    borderRadius: BorderRadius.circular(AppRadius.small),
                  ),
                  child: Text(
                    belumAdaHarga ? '—' : _rp.format(sisaTagihan(harga, dp)),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: (!belumAdaHarga && sisaTagihan(harga, dp) > 0)
                          ? AppColors.red
                          : AppColors.black,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s),
        LabeledField(
          label: 'Nota Servis untuk Jasa Pasang',
          hint: 'Biaya jasanya dicatat di nota itu, bukan di sini.',
          child: DropdownButtonFormField<String>(
            initialValue:
                notaPelanggan.any((n) => n.id == _notaId) ? _notaId : null,
            isExpanded: true,
            hint: Text(
              _pelanggan == null
                  ? 'Tautkan pelanggannya dulu'
                  : (notaPelanggan.isEmpty
                        ? 'Pelanggan ini belum punya nota servis'
                        : 'Belum ditautkan'),
            ),
            items: [
              for (final n in notaPelanggan)
                DropdownMenuItem(
                  value: n.id,
                  child: Text('${n.noNota}  ·  ${n.barangNama}'),
                ),
            ],
            onChanged: notaPelanggan.isEmpty
                ? null
                : (v) => setState(() => _notaId = v),
          ),
        ),
      ],
    );
  }

  Widget _kaki(BuildContext context) {
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
                    'Modal dan margin hanya terlihat oleh admin.',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
          ),
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
                : Text(widget.isNew ? 'SIMPAN' : 'SIMPAN PERUBAHAN'),
          ),
        ],
      ),
    );
  }
}
