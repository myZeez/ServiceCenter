// Prioritas omset: siapa yang masih di bawah target, kapan toko diingatkan,
// dan siapa yang sebaiknya diberi unit berikutnya.
//
// Yang dijaga: yang diukur rupiah, bukan jumlah unit; "sepuluh hari sebelum
// ganti bulan" berarti persis sepuluh hari terakhir di bulan 28, 29, 30,
// maupun 31 hari; dan antriannya kembali kosong sendiri begitu tanggalnya
// berganti.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sc_management/core/data/models.dart';
import 'package:sc_management/core/omset/omset_providers.dart';
import 'package:sc_management/core/omset/peringatan_omset.dart';
import 'package:sc_management/core/providers.dart';
import 'package:sc_management/features/service/antrian_teknisi.dart';
import 'package:sc_management/features/service/teknisi_ringkas.dart';

RingkasTeknisi _r(
  String id, {
  double omset = 0,
  double target = 4000000,
  int berjalan = 0,
}) => RingkasTeknisi(
  teknisi: Profile(id: id, nama: id, role: 'teknisi'),
  unitBerjalan: berjalan,
  notaSelesai: 0,
  omset: omset,
  target: target,
);

ServiceOrderEntry _nota(
  String id, {
  required String? teknisi,
  required DateTime masuk,
  String status = 'dikerjakan',
}) => ServiceOrderEntry(
  id: id,
  noNota: id,
  tanggalMasuk: masuk,
  customerNama: 'P',
  barangNama: 'ASUS',
  teknisiId: teknisi,
  status: status,
  updatedAt: masuk,
);

void main() {
  group('Sisa hari sebelum ganti bulan', () {
    test('hari terakhir bulan bernilai satu, bukan nol', () {
      expect(sisaHariSebelumGantiBulan(DateTime(2026, 9, 30)), 1);
      expect(sisaHariSebelumGantiBulan(DateTime(2026, 10, 31)), 1);
    });

    test('hari pertama bulan bernilai jumlah harinya', () {
      expect(sisaHariSebelumGantiBulan(DateTime(2026, 9, 1)), 30);
      expect(sisaHariSebelumGantiBulan(DateTime(2026, 10, 1)), 31);
    });

    test('Februari biasa dan kabisat', () {
      expect(sisaHariSebelumGantiBulan(DateTime(2026, 2, 28)), 1);
      expect(sisaHariSebelumGantiBulan(DateTime(2028, 2, 29)), 1);
      expect(sisaHariSebelumGantiBulan(DateTime(2028, 2, 1)), 29);
    });
  });

  group('Masa peringatan', () {
    test('sepuluh hari terakhir di bulan 30 hari: mulai tanggal 21', () {
      expect(masaPeringatanOmset(DateTime(2026, 9, 20), 10), isFalse);
      expect(masaPeringatanOmset(DateTime(2026, 9, 21), 10), isTrue);
      expect(masaPeringatanOmset(DateTime(2026, 9, 30), 10), isTrue);
    });

    test('di bulan 31 hari mulai tanggal 22, bukan 21', () {
      expect(masaPeringatanOmset(DateTime(2026, 10, 21), 10), isFalse);
      expect(masaPeringatanOmset(DateTime(2026, 10, 22), 10), isTrue);
    });

    test('Februari 28 hari: mulai tanggal 19', () {
      expect(masaPeringatanOmset(DateTime(2026, 2, 18), 10), isFalse);
      expect(masaPeringatanOmset(DateTime(2026, 2, 19), 10), isTrue);
    });

    test('bisa diatur, dan nol mematikannya', () {
      // Lima hari terakhir bulan 30 hari: 26, 27, 28, 29, 30.
      expect(masaPeringatanOmset(DateTime(2026, 9, 26), 5), isTrue);
      expect(masaPeringatanOmset(DateTime(2026, 9, 25), 5), isFalse);
      expect(masaPeringatanOmset(DateTime(2026, 9, 30), 0), isFalse);
      expect(masaPeringatanOmset(DateTime(2026, 9, 30), -3), isFalse);
    });

    test('bawaannya sepuluh hari', () {
      expect(hariPeringatanOmsetBawaan, 10);
    });
  });

  group('Di bawah target', () {
    test('diukur dengan rupiah', () {
      expect(dibawahTargetOmset(3999999, 4000000), isTrue);
      expect(dibawahTargetOmset(4000000, 4000000), isFalse);
      expect(dibawahTargetOmset(6375000, 4000000), isFalse);
    });

    test('tanpa target tidak ada yang kurang', () {
      expect(dibawahTargetOmset(0, 0), isFalse);
      expect(dibawahTargetOmset(100, -1), isFalse);
    });

    test('kurangnya tidak pernah negatif', () {
      expect(kurangDariTarget(860000, 4000000), 3140000);
      expect(kurangDariTarget(9340000, 4000000), 0);
    });

    test('ringkasan teknisi menyimpulkannya dari omset, bukan unit', () {
      // Lima puluh unit kecil tetap di bawah target; dua unit besar tidak.
      final banyakUnitKecil = RingkasTeknisi(
        teknisi: const Profile(id: 'a', nama: 'A', role: 'teknisi'),
        unitBerjalan: 51,
        notaSelesai: 59,
        omset: 3000000,
        target: 4000000,
      );
      final duaUnitBesar = RingkasTeknisi(
        teknisi: const Profile(id: 'b', nama: 'B', role: 'teknisi'),
        unitBerjalan: 0,
        notaSelesai: 2,
        omset: 5000000,
        target: 4000000,
      );
      expect(banyakUnitKecil.dibawahTarget, isTrue);
      expect(duaUnitBesar.dibawahTarget, isFalse);
    });
  });

  group('Urutan ringkasan teknisi', () {
    ProviderContainer wadah(List<ServiceOrderEntry> nota) {
      final c = ProviderContainer(
        overrides: [
          serviceOrdersProvider.overrideWith((ref) => Stream.value(nota)),
          allProfilesProvider.overrideWith(
            (ref) => Stream.value(const [
              Profile(id: 'aris', nama: 'Aris', role: 'teknisi'),
              Profile(id: 'daniel', nama: 'Daniel', role: 'teknisi'),
              Profile(id: 'reza', nama: 'Reza', role: 'teknisi'),
              Profile(id: 'admin', nama: 'admin', role: 'admin'),
            ]),
          ),
          omsetSettingsProvider.overrideWith(
            (ref) => Stream.value(
              const ServiceSettingsRow(
                id: 1,
                targetOmset: 4000000,
                feeAdminPerNota: 0,
              ),
            ),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    ServiceOrderEntry selesai(String id, String teknisi, double biaya) {
      final kini = DateTime.now();
      final hari = DateTime(kini.year, kini.month, 1);
      return ServiceOrderEntry(
        id: id,
        noNota: id,
        tanggalMasuk: hari,
        customerNama: 'P',
        barangNama: 'ASUS',
        teknisiId: teknisi,
        status: 'diambil',
        biaya: biaya,
        tanggalSelesai: hari,
        updatedAt: hari,
      );
    }

    test('omset terendah di depan, bukan yang paling banyak unitnya', () async {
      final c = wadah([
        selesai('1', 'aris', 4270000),
        selesai('2', 'reza', 3025000),
        selesai('3', 'daniel', 860000),
        selesai('4', 'admin', 9340000),
        // Aris memegang paling banyak unit yang masih berjalan.
        for (var i = 0; i < 6; i++)
          _nota('b$i', teknisi: 'aris', masuk: DateTime.now()),
      ]);
      await c.read(serviceOrdersProvider.future);
      await c.read(allProfilesProvider.future);
      await c.read(omsetSettingsProvider.future);

      final urut = c.read(ringkasTeknisiProvider);
      expect(urut.map((r) => r.teknisi.nama), [
        'Daniel',
        'Reza',
        'Aris',
        'admin',
      ]);
      expect(urut.map((r) => r.dibawahTarget), [true, true, false, false]);
    });

    test('yang sama persis (Rp0) diurutkan menurut nama, stabil', () async {
      final c = wadah(const []);
      await c.read(serviceOrdersProvider.future);
      await c.read(allProfilesProvider.future);
      await c.read(omsetSettingsProvider.future);

      expect(c.read(ringkasTeknisiProvider).map((r) => r.teknisi.nama), [
        'admin',
        'Aris',
        'Daniel',
        'Reza',
      ]);
    });
  });

  group('Antrian', () {
    final hari = DateTime(2026, 9, 21, 10);
    final pagi = DateTime(2026, 9, 21, 8);

    List<String> urutan(List<AntrianTeknisi> a) => [
      for (final x in a) x.teknisi.id,
    ];

    test('belum dapat kerja dan omset kurang paling depan', () {
      final a = susunAntrian(
        ringkas: [
          _r('sudahCukup', omset: 6000000),
          _r('belumCukup', omset: 5000000),
          _r('sudahKurang', omset: 1000000),
          _r('belumKurang', omset: 3000000),
        ],
        nota: [
          _nota('1', teknisi: 'sudahCukup', masuk: pagi),
          _nota('2', teknisi: 'sudahKurang', masuk: pagi),
        ],
        hari: hari,
      );

      // 0 belum+kurang, 1 belum+cukup, 2 sudah+kurang, 3 sudah+cukup.
      expect(urutan(a), [
        'belumKurang',
        'belumCukup',
        'sudahKurang',
        'sudahCukup',
      ]);
      expect(a.map((x) => x.tingkat), [0, 1, 2, 3]);
    });

    test('di dalam satu tingkat: yang paling sedikit nota, lalu omset', () {
      final a = susunAntrian(
        ringkas: [
          _r('dua', omset: 1000000),
          _r('satuBesar', omset: 3500000),
          _r('satuKecil', omset: 500000),
        ],
        nota: [
          _nota('1', teknisi: 'dua', masuk: pagi),
          _nota('2', teknisi: 'dua', masuk: pagi),
          _nota('3', teknisi: 'satuBesar', masuk: pagi),
          _nota('4', teknisi: 'satuKecil', masuk: pagi),
        ],
        hari: hari,
      );

      // Semuanya sudah dapat kerja dan kurang: satu nota dahulu (omset
      // terendah di depan), dua nota terakhir.
      expect(urutan(a), ['satuKecil', 'satuBesar', 'dua']);
    });

    test('nama menentukan bila semuanya sama persis', () {
      final a = susunAntrian(
        ringkas: [_r('Reza'), _r('Aris'), _r('Daniel')],
        nota: const [],
        hari: hari,
      );
      expect(urutan(a), ['Aris', 'Daniel', 'Reza']);
    });

    test('kembali kosong sendiri begitu tanggalnya berganti', () {
      final ringkas = [_r('budi'), _r('agus')];
      final nota = [
        _nota('1', teknisi: 'budi', masuk: DateTime(2026, 9, 21, 9)),
      ];

      final hariIni = susunAntrian(ringkas: ringkas, nota: nota, hari: hari);
      expect(hariIni.firstWhere((x) => x.teknisi.id == 'budi').notaHariIni, 1);
      expect(urutan(hariIni).first, 'agus');

      // Besoknya: nota kemarin tidak dihitung lagi, semuanya belum dapat.
      final besok = susunAntrian(
        ringkas: ringkas,
        nota: nota,
        hari: DateTime(2026, 9, 22, 8),
      );
      expect(besok.every((x) => x.notaHariIni == 0), isTrue);
      expect(besok.every((x) => x.belumDapatKerja), isTrue);
    });

    test('nota yang dibatalkan tidak dihitung sebagai pekerjaan', () {
      final a = susunAntrian(
        ringkas: [_r('budi')],
        nota: [_nota('1', teknisi: 'budi', masuk: pagi, status: 'batal')],
        hari: hari,
      );
      expect(a.single.belumDapatKerja, isTrue);
    });

    test('nota tanpa teknisi tidak jatuh ke siapa pun', () {
      final a = susunAntrian(
        ringkas: [_r('budi')],
        nota: [_nota('1', teknisi: null, masuk: pagi)],
        hari: hari,
      );
      expect(a.single.notaHariIni, 0);
    });

    test('sudah cukup omsetnya tetap masuk antrian, hanya di belakang', () {
      final a = susunAntrian(
        ringkas: [_r('admin', omset: 9340000), _r('daniel', omset: 860000)],
        nota: [_nota('1', teknisi: 'daniel', masuk: pagi)],
        hari: hari,
      );
      // Admin belum dapat kerja (tingkat 1) mendahului Daniel yang sudah
      // dapat kerja (tingkat 2).
      expect(urutan(a), ['admin', 'daniel']);
      expect(a.first.perluPushOmset, isFalse);
      expect(a.last.perluPushOmset, isTrue);
    });
  });

  group('Pengaturan', () {
    test('kolom hari peringatan dibaca', () {
      final s = ServiceSettingsRow.fromMap({
        'id': 1,
        'target_omset': 4000000,
        'fee_admin_per_nota': 0,
        'hari_peringatan_omset': 7,
      });
      expect(s.hariPeringatanOmset, 7);
    });

    test('database yang belum dimigrasi memakai sepuluh hari', () {
      final s = ServiceSettingsRow.fromMap({
        'id': 1,
        'target_omset': 4000000,
        'fee_admin_per_nota': 0,
      });
      expect(s.hariPeringatanOmset, 10);
    });
  });
}
