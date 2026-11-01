import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/import/banding_impor.dart';
import '../../core/import/legacy_sql.dart';
import '../../core/import/svs_xlsx.dart';
import '../../core/providers.dart';

/// Impor backup aplikasi lama, dengan buku SVS sebagai data pendukung.
///
/// Tidak ada yang ditulis sebelum CEK DATA: setiap nota di file dipilah
/// menjadi baru, perlu koreksi, sama, atau perlu diperiksa, dan admin
/// mencentang yang mau diterapkan.
class SqlImportDialog extends ConsumerStatefulWidget {
  const SqlImportDialog({super.key});

  @override
  ConsumerState<SqlImportDialog> createState() => _SqlImportDialogState();
}

class _SqlImportDialogState extends ConsumerState<SqlImportDialog> {
  // Sampai berkas terbaca, rentangnya sudah mencakup bulan lalu; sesudah itu
  // rentang mengikuti isi berkas (lihat rentangBawaanImpor).
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month - 1);
  DateTime _to = DateTime.now();
  DateTime? _akhirBackup;
  List<NotaBackup> _backup = [];
  BukuSvs? _svs;
  String? _fileBackup, _fileSvs, _error;
  List<BarisBanding>? _hasil;
  final Set<int> _dipilih = {};
  KategoriImpor? _saring;
  Map<String, dynamic>? _diterapkan;
  bool _busy = false;

  String _date(DateTime d) => d.toIso8601String().substring(0, 10);
  String _tgl(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  /// Hasil cek tidak berlaku lagi begitu masukannya berubah.
  void _lupakanHasil() {
    _hasil = null;
    _dipilih.clear();
    _saring = null;
    _diterapkan = null;
  }

  Future<void> _pickDate(bool start) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _from : _to,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() {
        // Ujung yang satunya ikut bergeser, supaya mengganti tanggal ke
        // bulan lalu tidak berakhir di "rentang terbalik".
        if (start) {
          _from = picked;
          if (_to.isBefore(picked)) _to = picked;
        } else {
          _to = picked;
          if (_from.isAfter(picked)) {
            _from = DateTime(picked.year, picked.month);
          }
        }
        _lupakanHasil();
      });
    }
  }

  Future<void> _kerja(Future<void> Function() isi) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await isi();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pilihBackup() async {
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(label: 'Backup SQL', extensions: ['sql', 'SQL']),
      ],
    );
    if (file == null || !mounted) return;
    await _kerja(() async {
      setState(() {
        _fileBackup = file.name;
        _backup = [];
        _akhirBackup = null;
        _lupakanHasil();
      });
      if (await file.length() > 100 * 1024 * 1024) {
        throw const FormatException('File melebihi 100 MB.');
      }
      final text = utf8.decode(await file.readAsBytes());
      final rows = await compute(parseLegacySql, text);
      if (mounted) {
        final backup = [for (final r in rows) NotaBackup.fromMap(r)];
        final rentang = rentangBawaanImpor(backup, DateTime.now());
        setState(() {
          _backup = backup;
          _from = rentang.dari;
          _to = rentang.sampai;
          _akhirBackup = rentang.sampai;
        });
      }
    });
  }

  /// Boleh beberapa berkas: rentang yang melewati akhir bulan butuh buku
  /// bulan itu dan buku bulan berikutnya.
  Future<void> _pilihSvs() async {
    final files = await openFiles(
      acceptedTypeGroups: [
        const XTypeGroup(label: 'Buku SVS', extensions: ['xlsx', 'XLSX']),
      ],
    );
    if (files.isEmpty || !mounted) return;
    await _kerja(() async {
      setState(() {
        _fileSvs = files.length == 1
            ? files.single.name
            : '${files.length} BERKAS SVS';
        _svs = null;
        _lupakanHasil();
      });
      final buku = [
        for (final f in files)
          await compute(bacaSvsXlsx, await f.readAsBytes()),
      ];
      if (mounted) setState(() => _svs = gabungBukuSvs(buku));
    });
  }

  Future<void> _cek() => _kerja(() async {
    if (_from.isAfter(_to)) {
      throw const FormatException('Rentang tanggal terbalik.');
    }
    final nota = ref.read(serviceOrdersProvider).valueOrNull;
    final profil = ref.read(allProfilesProvider).valueOrNull;
    final metode = ref.read(allMetodeBayarProvider).valueOrNull;
    if (nota == null || profil == null || metode == null) {
      throw const FormatException(
        'Data aplikasi belum termuat penuh. Tunggu sebentar lalu cek lagi.',
      );
    }
    final hasil = bandingkanImpor(
      backup: _backup,
      svs: _svs,
      konteks: KonteksImpor(
        nota: nota,
        profil: profil,
        metodeBayar: {for (final m in metode) m.kode},
        jamTutup: ref.read(jamTutupProvider),
        libur: ref.read(hariLiburProvider),
      ),
      dari: _from,
      sampai: _to,
    );
    if (hasil.isEmpty) {
      final akhir = _akhirBackup;
      throw FormatException(
        'Tidak ada nota yang masuk atau keluar dalam rentang tanggal ini.'
        '${akhir == null ? '' : ' Data terakhir di backup: ${_tgl(akhir)}.'}',
      );
    }
    setState(() {
      _lupakanHasil();
      _hasil = hasil;
      _dipilih.addAll([
        for (final h in hasil)
          if (_bisaDipilih(h)) h.urut,
      ]);
      _saring = [
        KategoriImpor.koreksi,
        KategoriImpor.baru,
        KategoriImpor.periksa,
        KategoriImpor.sama,
      ].firstWhere((k) => hasil.any((h) => h.kategori == k));
    });
  });

  bool _bisaDipilih(BarisBanding h) =>
      h.kategori == KategoriImpor.baru || h.kategori == KategoriImpor.koreksi;

  Future<void> _terapkan() => _kerja(() async {
    final pilihan = [
      for (final h in _hasil ?? const <BarisBanding>[])
        if (_dipilih.contains(h.urut) && _bisaDipilih(h)) h,
    ];
    final baru = [
      for (final h in pilihan)
        if (h.notaBaru != null) h.notaBaru!,
    ];
    final ubah = [
      for (final h in pilihan)
        if (h.ubah != null) h.ubah!,
    ];
    if (baru.isEmpty && ubah.isEmpty) {
      throw const FormatException('Belum ada nota yang dicentang.');
    }
    final hasil = await Supabase.instance.client.rpc(
      'terapkan_impor_servis',
      params: {'p_baru': baru, 'p_ubah': ubah},
    );
    if (mounted) {
      setState(() {
        _diterapkan = Map<String, dynamic>.from(hasil as Map);
        _hasil = null;
        _dipilih.clear();
      });
    }
  });

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final hasil = _hasil;
    final svs = _svs;
    final lewatRentang =
        svs != null && (svs.akhir.isBefore(_from) || svs.awal.isAfter(_to));
    final jumlahDipilih = hasil == null
        ? 0
        : hasil
              .where((h) => _dipilih.contains(h.urut) && _bisaDipilih(h))
              .length;

    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: const Text('Impor backup SQL'),
        content: SizedBox(
          width: 640,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Backup aplikasi lama (_SP4.SQL) menentukan nota yang ada, '
                  'teknisinya, dan unit yang sudah keluar. Buku SVS (xlsx) '
                  'melengkapi cara bayar, biaya, perbaikan, dan keluhan. '
                  'Tanpa SVS, isi database dipertahankan.',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _pilihBackup,
                      icon: const Icon(Icons.upload_file),
                      label: Text(_fileBackup ?? 'PILIH BACKUP SQL'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _pilihSvs,
                      icon: const Icon(Icons.table_view_outlined),
                      label: Text(_fileSvs ?? 'PILIH SVS (BOLEH BEBERAPA)'),
                    ),
                    if (_fileSvs != null)
                      IconButton(
                        tooltip: 'Lepas berkas SVS',
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                _fileSvs = null;
                                _svs = null;
                                _lupakanHasil();
                              }),
                        icon: const Icon(Icons.close),
                      ),
                  ],
                ),
                if (_backup.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${_backup.length} nota pada backup, data terakhir '
                      '${_tgl(_akhirBackup!)}.',
                    ),
                  ),
                if (svs != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'SVS ${_tgl(svs.awal)} - ${_tgl(svs.akhir)} '
                      '(${svs.hari.length} lembar): ${svs.masuk.length} masuk, '
                      '${svs.keluar.length} keluar.'
                      '${svs.peringatan.isEmpty ? '' : ' ${svs.peringatan.length} peringatan.'}',
                    ),
                  ),
                if (lewatRentang)
                  Text(
                    'Tanggal SVS ini di luar rentang yang dipilih; '
                    'isinya tidak akan terpakai.',
                    style: TextStyle(color: skema.error),
                  ),
                Wrap(
                  spacing: 12,
                  children: [
                    TextButton(
                      onPressed: _busy ? null : () => _pickDate(true),
                      child: Text('Dari: ${_date(_from)}'),
                    ),
                    TextButton(
                      onPressed: _busy ? null : () => _pickDate(false),
                      child: Text('Sampai: ${_date(_to)}'),
                    ),
                  ],
                ),
                const Text(
                  'Rentang mencakup nota yang masuk ATAU keluar pada tanggal itu, '
                  'dan boleh mundur ke bulan-bulan sebelumnya. Nota yang sudah '
                  'sama tidak disentuh.',
                ),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: LinearProgressIndicator(),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_error!, style: TextStyle(color: skema.error)),
                  ),
                if (_diterapkan != null) _RingkasanTerapkan(_diterapkan!),
                if (hasil != null) ..._daftarHasil(context, hasil),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('TUTUP'),
          ),
          OutlinedButton(
            onPressed: _busy || _backup.isEmpty ? null : _cek,
            child: const Text('CEK DATA'),
          ),
          FilledButton(
            onPressed: _busy || jumlahDipilih == 0 ? null : _terapkan,
            child: Text(
              jumlahDipilih == 0 ? 'TERAPKAN' : 'TERAPKAN ($jumlahDipilih)',
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _daftarHasil(BuildContext context, List<BarisBanding> hasil) {
    final skema = Theme.of(context).colorScheme;
    int hitung(KategoriImpor k) => hasil.where((h) => h.kategori == k).length;
    final tampil = hasil.where((h) => h.kategori == _saring).toList();
    final perluBayar = hasil.where((h) => h.perluCaraBayar).length;
    final bisaPilih = tampil.where(_bisaDipilih).toList();
    return [
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final (k, label) in const [
            (KategoriImpor.koreksi, 'Perlu koreksi'),
            (KategoriImpor.baru, 'Baru'),
            (KategoriImpor.periksa, 'Perlu diperiksa'),
            (KategoriImpor.sama, 'Sama'),
          ])
            ChoiceChip(
              label: Text('$label ${hitung(k)}'),
              selected: _saring == k,
              onSelected: hitung(k) == 0
                  ? null
                  : (_) => setState(() => _saring = k),
            ),
        ],
      ),
      if (perluBayar > 0)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '$perluBayar nota sudah diambil dengan bayar tetapi cara bayarnya '
            'belum diketahui${_svs == null ? '. Sertakan buku SVS untuk melengkapinya.' : ' di SVS ini.'}',
            style: TextStyle(color: skema.error),
          ),
        ),
      if (bisaPilih.isNotEmpty)
        Row(
          children: [
            TextButton(
              onPressed: () =>
                  setState(() => _dipilih.addAll(bisaPilih.map((h) => h.urut))),
              child: const Text('Centang semua'),
            ),
            TextButton(
              onPressed: () => setState(
                () => _dipilih.removeAll(bisaPilih.map((h) => h.urut)),
              ),
              child: const Text('Kosongkan'),
            ),
          ],
        ),
      SizedBox(
        height: 360,
        child: ListView.separated(
          itemCount: tampil.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) => _BarisHasil(
            hasil: tampil[i],
            profil: {
              for (final p
                  in ref.read(allProfilesProvider).valueOrNull ?? const [])
                p.id: p.nama,
            },
            dipilih: _dipilih.contains(tampil[i].urut),
            bisaDipilih: _bisaDipilih(tampil[i]),
            aktif: !_busy,
            ubahPilihan: (v) => setState(() {
              if (v) {
                _dipilih.add(tampil[i].urut);
              } else {
                _dipilih.remove(tampil[i].urut);
              }
            }),
          ),
        ),
      ),
    ];
  }
}

class _BarisHasil extends StatelessWidget {
  const _BarisHasil({
    required this.hasil,
    required this.profil,
    required this.dipilih,
    required this.bisaDipilih,
    required this.aktif,
    required this.ubahPilihan,
  });

  final BarisBanding hasil;
  final Map<String, String> profil;
  final bool dipilih;
  final bool bisaDipilih;
  final bool aktif;
  final ValueChanged<bool> ubahPilihan;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final redup = TextStyle(color: tema.colorScheme.onSurfaceVariant);
    final baru = hasil.notaBaru;
    final baris = <Widget>[
      if (baru != null)
        Text(
          [
            'Ditambahkan: ${baru['status']}',
            if (baru['garansi'] == true) 'garansi',
            if ((baru['biaya'] as num) > 0)
              'Rp${(baru['biaya'] as num).round()}',
            if (baru['cara_bayar'] != null) '${baru['cara_bayar']}',
            if (baru['tanggal_diambil'] != null)
              'keluar ${baru['tanggal_diambil']}',
            'teknisi ${profil[baru['teknisi_id']] ?? '-'}',
          ].join(', '),
        ),
      for (final u in hasil.usulan)
        Text('${u.label}: ${u.dari} -> ${u.ke}  (${u.sumber})'),
      for (final c in hasil.catatan) Text(c, style: redup),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: bisaDipilih && dipilih,
          onChanged: bisaDipilih && aktif
              ? (v) => ubahPilihan(v ?? false)
              : null,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${hasil.noNota}  ${hasil.nama}',
                  style: tema.textTheme.titleSmall,
                ),
                ...baris,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RingkasanTerapkan extends StatelessWidget {
  const _RingkasanTerapkan(this.hasil);

  final Map<String, dynamic> hasil;

  @override
  Widget build(BuildContext context) {
    final lewat = (hasil['dilewati'] as List?) ?? const [];
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Impor berhasil: ${hasil['baru']} nota baru, '
            '${hasil['diubah']} nota dikoreksi.',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (lewat.isNotEmpty) ...[
            Text('Dilewati ${lewat.length}:'),
            for (final l in lewat.take(30))
              Text(
                '${(l as Map)['no_nota'] ?? l['id']}: ${l['alasan']}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
          const Text(
            'Tekan CEK DATA lagi untuk memastikan semuanya sudah sama.',
          ),
        ],
      ),
    );
  }
}
