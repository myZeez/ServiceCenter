import 'dart:ui';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/local/database.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/swiss_widgets.dart';
import '../scan/scan_page.dart';
import 'service_status.dart';

const _uuid = Uuid();
final _tglFmt = DateFormat('dd MMM yyyy');
final _iso = DateFormat('yyyy-MM-dd');

Future<void> showServiceDialog(BuildContext context, {ServiceOrderEntry? nota}) {
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

  String? _teknisiId;
  int? _brandId;
  DateTime? _estimasi;
  bool _garansi = false;
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
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _kosongNull(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) return;
    if (_garansi && _brandId == null && widget.isNew) {
      setState(() => _error = 'Pilih brand untuk klaim garansinya.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final client = ref.read(supabaseProvider);
    final user = ref.read(currentUserProvider);

    try {
      String? claimId = widget.nota?.claimId;

      // Unit bergaransi menghasilkan dua catatan sekaligus: nota untuk
      // pelanggan, dan klaim untuk brand. Datanya diketik satu kali.
      if (widget.isNew && _garansi) {
        claimId = _uuid.v4();
        final now = DateTime.now();

        await ref.read(databaseProvider).upsertClaimLocal(
              ClaimsCompanion.insert(
                id: claimId,
                tanggal: now,
                brandId: _brandId!,
                namaPelanggan: _nama.text.trim(),
                telp: Value(_kosongNull(_telp)),
                sn: _sn.text.trim(),
                teknisiId: Value(_teknisiId),
                keluhan: Value(_kosongNull(_keluhan)),
                status: const Value('open'),
                createdBy: user!.id,
                createdAt: now,
                updatedAt: now,
                syncPending: const Value(true),
              ),
            );
        // Klaimnya harus sudah ada di server sebelum nota menunjuk padanya.
        await ref.read(syncServiceProvider).syncNow();
      }

      final data = {
        'estimasi_selesai':
            _estimasi == null ? null : _iso.format(_estimasi!),
        'customer_nama': _nama.text.trim(),
        'customer_telp': _kosongNull(_telp),
        'operator_id': user?.id,
        'barang_nama': _barang.text.trim(),
        'barang_type': _kosongNull(_type),
        'barang_sn': _kosongNull(_sn),
        'kelengkapan': _kosongNull(_kelengkapan),
        'keluhan': _kosongNull(_keluhan),
        'teknisi_id': _teknisiId,
        'perbaikan': _kosongNull(_perbaikan),
        'garansi': _garansi,
        'claim_id': claimId,
        'status': _status,
        'biaya': double.tryParse(_biaya.text) ?? 0,
        'cara_bayar': _caraBayar,
        'tanggal_lunas':
            _tanggalLunas == null ? null : _iso.format(_tanggalLunas!),
        'keterangan': _kosongNull(_keterangan),
      };

      if (widget.isNew) {
        await client.from('service_orders').insert(data);
      } else {
        await client
            .from('service_orders')
            .update(data)
            .eq('id', widget.nota!.id);
      }

      await ref.read(syncServiceProvider).syncNow();

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isNew ? 'Nota tersimpan' : 'Nota diperbarui'),
        ),
      );
    } on PostgrestException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(
        () => _error = 'Gagal menyimpan. Membuat nota membutuhkan koneksi, '
            'karena nomornya ditetapkan server agar tidak kembar.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final techs = ref.watch(techniciansProvider).valueOrNull ?? const <Profile>[];
    final brands = ref.watch(brandsProvider).valueOrNull ?? const <Brand>[];
    final size = MediaQuery.sizeOf(context);

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
                      : _tglFmt.format(n.tanggalMasuk),
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
        LabeledField(
          label: 'Nama',
          required: true,
          child: TextFormField(
            controller: _nama,
            autofocus: widget.isNew,
            textCapitalization: TextCapitalization.characters,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
          ),
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
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Wajib diisi'
                      : null,
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
          child: TextFormField(
            controller: _sn,
            textCapitalization: TextCapitalization.characters,
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
                      initialDate: _estimasi ??
                          DateTime.now().add(const Duration(days: 3)),
                      firstDate: DateTime.now()
                          .subtract(const Duration(days: 365)),
                      lastDate:
                          DateTime.now().add(const Duration(days: 365)),
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
        CheckboxListTile(
          value: _garansi,
          onChanged: widget.isNew
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
            widget.isNew
                ? 'Klaim ke brand dibuat otomatis dari data ini.'
                : 'Tidak bisa diubah setelah nota tersimpan.',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
        if (_garansi && widget.isNew) ...[
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
                child: TextFormField(
                  controller: _biaya,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                  initialValue: _caraBayar,
                  isExpanded: true,
                  hint: const Text('—'),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'piutang', child: Text('Piutang')),
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
                      lastDate:
                          DateTime.now().add(const Duration(days: 365)),
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
  padding: const EdgeInsets.symmetric(
    horizontal: AppSpacing.s,
    vertical: 13,
  ),
);
