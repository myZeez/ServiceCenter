import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/import/legacy_sql.dart';

class SqlImportDialog extends StatefulWidget {
  const SqlImportDialog({super.key});

  @override
  State<SqlImportDialog> createState() => _SqlImportDialogState();
}

class _SqlImportDialogState extends State<SqlImportDialog> {
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _to = DateTime.now();
  List<Map<String, dynamic>> _rows = [];
  Map<String, dynamic>? _preview;
  String? _file, _error;
  bool _busy = false, _done = false;
  bool _syncTechnicians = true;

  String _date(DateTime d) => d.toIso8601String().substring(0, 10);
  List<Map<String, dynamic>> get _selected => _rows
      .where(
        (r) =>
            (r['tanggal_masuk'] as String).compareTo(_date(_from)) >= 0 &&
            (r['tanggal_masuk'] as String).compareTo(_date(_to)) <= 0,
      )
      .toList();

  Future<void> _pickDate(bool start) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _from : _to,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() {
        if (start) {
          _from = picked;
        } else {
          _to = picked;
        }
        _preview = null;
        _done = false;
      });
    }
  }

  Future<void> _choose() async {
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(label: 'Backup SQL', extensions: ['sql', 'SQL']),
      ],
    );
    if (file == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
      _preview = null;
      _rows = [];
      _done = false;
      _file = file.name;
    });
    try {
      if (await file.length() > 100 * 1024 * 1024) {
        throw const FormatException('File melebihi 100 MB.');
      }
      final text = utf8.decode(await file.readAsBytes());
      final rows = await compute(parseLegacySql, text);
      if (mounted) setState(() => _rows = rows);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _run(bool apply) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final rows = _selected;
      if (_from.isAfter(_to)) {
        throw const FormatException('Rentang tanggal terbalik.');
      }
      if (rows.isEmpty) {
        throw const FormatException(
          'Tidak ada nota dalam rentang tanggal ini.',
        );
      }
      if (rows.length > 5000) {
        throw const FormatException(
          'Pilih rentang maksimal 5.000 nota per impor.',
        );
      }
      final result = await Supabase.instance.client.rpc(
        'impor_backup_servis',
        params: {
          'p_rows': rows,
          'p_apply': apply,
          'p_sync_teknisi': _syncTechnicians,
        },
      );
      if (mounted) {
        setState(() {
          _preview = Map<String, dynamic>.from(result as Map);
          _done = apply;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Impor belum berhasil. $e';
          _preview = null;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('Impor backup SQL'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pilih backup aplikasi lama (_SP4.SQL) terbaru. Rentang tanggal mengacu ke tanggal masuk nota.',
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy ? null : _choose,
                icon: const Icon(Icons.upload_file),
                label: Text(_file ?? 'PILIH FILE SQL'),
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
              if (_rows.isNotEmpty)
                Text(
                  '${_rows.length} nota pada file • ${_selected.length} dalam rentang',
                ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Samakan teknisi nota yang sudah ada'),
                subtitle: const Text(
                  'Teknisi kosong pada file tetap memakai penugasan yang sudah ada.',
                ),
                value: _syncTechnicians,
                onChanged: _busy
                    ? null
                    : (v) => setState(() {
                        _syncTechnicians = v!;
                        _preview = null;
                        _done = false;
                      }),
              ),
              const Text(
                'Nota baru ditambahkan beserta status dan tanggal keluar. Biaya, pelunasan, garansi, dan status nota yang sudah ada tetap dipertahankan. Backup lama tidak memiliki bukti pelunasan; nota baru berbiaya perlu dikroscek pembayarannya.',
              ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: LinearProgressIndicator(),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (_preview != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    '${_done ? "Impor berhasil" : "Ringkasan impor"}\n'
                    'Nota baru: ${_preview!["baru"]}\n'
                    'Teknisi diperbarui: ${_preview!["teknisi_diubah"]}\n'
                    'Nota sudah sesuai: ${_preview!["tetap"]}\n'
                    'Teknisi belum terdaftar: ${(_preview!["teknisi_tidak_dikenal"] as List).join(", ")}\n'
                    'Nota sumber tanpa teknisi: ${_preview!["tanpa_teknisi"]}',
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('TUTUP'),
        ),
        if (!_done)
          OutlinedButton(
            onPressed: _busy || _rows.isEmpty ? null : () => _run(false),
            child: const Text('CEK DATA'),
          ),
        if (!_done)
          FilledButton(
            onPressed: _busy || _preview == null ? null : () => _run(true),
            child: const Text('IMPOR KE DATABASE'),
          ),
      ],
    ),
  );
}
