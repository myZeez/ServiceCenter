// Beban dan omset tiap teknisi. Angkanya dipakai untuk memutuskan siapa
// yang diberi unit berikutnya, dan dibaca teknisi sendiri sebagai capaian
// terhadap targetnya -- keduanya salah kalau perhitungannya meleset.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sc_management/core/data/models.dart';
import 'package:sc_management/core/omset/omset_providers.dart';
import 'package:sc_management/core/providers.dart';
import 'package:sc_management/features/service/service_view.dart'
    show serviceOrdersProvider;
import 'package:sc_management/features/service/teknisi_ringkas.dart';

final _kini = DateTime.now();
final _bulanIni = DateTime(_kini.year, _kini.month, 15);
final _bulanLalu = DateTime(_kini.year, _kini.month - 1, 15);

ServiceOrderEntry _nota({
  required String id,
  String? teknisi,
  String status = 'diambil',
  double biaya = 0,
  DateTime? selesai,
}) => ServiceOrderEntry(
  id: id,
  noNota: id,
  tanggalMasuk: _bulanIni,
  customerNama: 'Pelanggan',
  barangNama: 'ASUS',
  teknisiId: teknisi,
  status: status,
  biaya: biaya,
  tanggalSelesai: selesai,
  updatedAt: _bulanIni,
);

Profile _orang(String id, String nama) =>
    Profile(id: id, nama: nama, role: 'teknisi');

ProviderContainer _wadah({
  required List<ServiceOrderEntry> nota,
  List<Profile>? orang,
  double target = 4000000,
}) {
  final c = ProviderContainer(
    overrides: [
      serviceOrdersProvider.overrideWith((ref) => Stream.value(nota)),
      allProfilesProvider.overrideWith(
        (ref) => Stream.value(orang ?? [_orang('t1', 'Reza')]),
      ),
      omsetSettingsProvider.overrideWith(
        (ref) => Stream.value(
          ServiceSettingsRow(id: 1, targetOmset: target, feeAdminPerNota: 0),
        ),
      ),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

Future<void> _siap(ProviderContainer c) async {
  await c.read(serviceOrdersProvider.future);
  await c.read(allProfilesProvider.future);
  await c.read(omsetSettingsProvider.future);
}

void main() {
  group('Unit sedang dikerjakan', () {
    test('menghitung yang belum tuntas saja', () async {
      final c = _wadah(
        nota: [
          _nota(id: '1', teknisi: 't1', status: 'masuk'),
          _nota(id: '2', teknisi: 't1', status: 'dikerjakan'),
          _nota(id: '3', teknisi: 't1', status: 'tunggu_part'),
          // Sudah rampung, tinggal menunggu diambil: bukan beban lagi.
          _nota(id: '4', teknisi: 't1', status: 'selesai'),
          _nota(id: '5', teknisi: 't1', status: 'diambil'),
          _nota(id: '6', teknisi: 't1', status: 'batal'),
        ],
      );
      await _siap(c);

      expect(c.read(ringkasTeknisiProvider).single.unitBerjalan, 3);
    });

    test('unit tanpa teknisi tidak dibebankan kepada siapa pun', () async {
      final c = _wadah(
        nota: [
          _nota(id: '1', status: 'dikerjakan'),
          _nota(id: '2', teknisi: 't1', status: 'dikerjakan'),
        ],
      );
      await _siap(c);

      expect(c.read(ringkasTeknisiProvider).single.unitBerjalan, 1);
    });
  });

  group('Omset bulan berjalan', () {
    test('hanya nota yang selesai bulan ini yang dihitung', () async {
      final c = _wadah(
        nota: [
          _nota(
            id: '1',
            teknisi: 't1',
            biaya: 300000,
            selesai: _bulanIni,
          ),
          _nota(
            id: '2',
            teknisi: 't1',
            biaya: 500000,
            selesai: _bulanLalu,
          ),
        ],
      );
      await _siap(c);

      final r = c.read(ringkasTeknisiProvider).single;
      expect(r.omset, 300000);
      expect(r.notaSelesai, 1);
    });

    test('nota batal tidak ikut walau ada biayanya', () async {
      final c = _wadah(
        nota: [
          _nota(
            id: '1',
            teknisi: 't1',
            biaya: 300000,
            selesai: _bulanIni,
            status: 'batal',
          ),
        ],
      );
      await _siap(c);

      expect(c.read(ringkasTeknisiProvider).single.omset, 0);
    });

    test('nota yang belum lunas tetap masuk omset', () async {
      // Omset adalah pekerjaan yang dihasilkan, bukan uang yang sudah
      // diterima. Piutang tetap hasil kerja teknisinya.
      final c = _wadah(
        nota: [
          _nota(id: '1', teknisi: 't1', biaya: 250000, selesai: _bulanIni),
        ],
      );
      await _siap(c);

      expect(c.read(ringkasTeknisiProvider).single.omset, 250000);
    });
  });

  group('Target', () {
    test('sisa dan persentase dihitung terhadap target', () async {
      final c = _wadah(
        nota: [
          _nota(id: '1', teknisi: 't1', biaya: 1000000, selesai: _bulanIni),
        ],
      );
      await _siap(c);

      final r = c.read(ringkasTeknisiProvider).single;
      expect(r.persenTarget, 25);
      expect(r.kurang, 3000000);
    });

    test('yang melampaui target tidak berkekurangan negatif', () async {
      final c = _wadah(
        nota: [
          _nota(id: '1', teknisi: 't1', biaya: 5000000, selesai: _bulanIni),
        ],
      );
      await _siap(c);

      expect(c.read(ringkasTeknisiProvider).single.kurang, 0);
    });
  });

  group('Urutan', () {
    test('yang sedang memegang unit paling banyak di depan', () async {
      final c = _wadah(
        orang: [_orang('t1', 'Reza'), _orang('t2', 'Andi')],
        nota: [
          _nota(id: '1', teknisi: 't2', status: 'dikerjakan'),
          _nota(id: '2', teknisi: 't2', status: 'dikerjakan'),
          _nota(id: '3', teknisi: 't1', status: 'dikerjakan'),
        ],
      );
      await _siap(c);

      expect(
        c.read(ringkasTeknisiProvider).map((r) => r.teknisi.nama),
        ['Andi', 'Reza'],
      );
    });

    test('teknisi tanpa pekerjaan tetap muncul', () async {
      // Kartunya justru berguna saat kosong: itu tanda dia bisa diberi unit
      // berikutnya.
      final c = _wadah(
        orang: [_orang('t1', 'Reza'), _orang('t2', 'Andi')],
        nota: [],
      );
      await _siap(c);

      expect(c.read(ringkasTeknisiProvider).length, 2);
      expect(c.read(ringkasTeknisiProvider).every((r) => r.omset == 0), isTrue);
    });
  });
}
