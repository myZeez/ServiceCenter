// Membandingkan backup aplikasi lama (dan SVS) dengan database sebelum impor.
//
// Setiap kasus di sini pernah terjadi pada data Oktober 2026: nota yang
// sudah diambil tetapi di database masih "masuk", nota kembar sisa impor
// September, nota Sabtu yang nomornya ikut lembar Jumat, dan nota berbayar
// yang cara bayarnya hanya ada di buku SVS.

import 'package:flutter_test/flutter_test.dart';
import 'package:sc_management/core/data/models.dart';
import 'package:sc_management/core/import/banding_impor.dart';
import 'package:sc_management/core/import/svs_xlsx.dart';

const _profil = [
  Profile(id: 'p-agus', nama: 'Agus', role: 'teknisi'),
  Profile(id: 'p-budi', nama: 'Budi', role: 'teknisi'),
  Profile(id: 'p-admin', nama: 'Admin', role: 'admin'),
];
const _metode = {'cash', 'qris', 'qr_btn', 'transfer_bri', 'piutang'};

String _no(DateTime t, int urut) =>
    'SVR-${t.day.toString().padLeft(2, '0')}${t.month.toString().padLeft(2, '0')}${t.year % 100}$urut';

NotaBackup _bk(
  int urut, {
  DateTime? masuk,
  String status = 'masuk',
  bool garansi = false,
  double biaya = 0,
  DateTime? diambil,
  String? jam,
  String teknisi = 'AGUS',
  String nama = 'AKHSAN',
  String? keluhan = 'MATI TOTAL',
}) {
  final t = masuk ?? DateTime(2026, 10, 16);
  return NotaBackup(
    urut: urut,
    noNota: _no(t, urut),
    tanggalMasuk: t,
    nama: nama,
    telp: '082253237884',
    barang: 'UPS PROLINK',
    keluhan: keluhan,
    teknisi: teknisi,
    status: status,
    garansi: garansi,
    biaya: biaya,
    tanggalDiambil: diambil,
    jamDiambil: jam,
  );
}

ServiceOrderEntry _db(
  int urut, {
  DateTime? masuk,
  String? noNota,
  String status = 'masuk',
  String? teknisi = 'p-agus',
  bool garansi = false,
  double biaya = 0,
  String? cara,
  DateTime? lunas,
  DateTime? selesai,
  DateTime? diambil,
  String nama = 'Akhsan',
  String? keluhan = 'Mati Total',
}) {
  final t = masuk ?? DateTime(2026, 10, 16);
  return ServiceOrderEntry(
    id: 'id-$urut-${noNota ?? ''}',
    noNota: noNota ?? _no(t, urut),
    tanggalMasuk: t,
    customerNama: nama,
    customerTelp: '0822-5323-7884',
    barangNama: 'Ups Prolink',
    keluhan: keluhan,
    teknisiId: teknisi,
    status: status,
    garansi: garansi,
    biaya: biaya,
    caraBayar: cara,
    tanggalLunas: lunas,
    tanggalSelesai: selesai,
    tanggalDiambil: diambil,
    updatedAt: DateTime.utc(2026, 10, 15, 11, 54, 38, 96, 426),
  );
}

List<BarisBanding> _banding(
  List<NotaBackup> backup, {
  List<ServiceOrderEntry> db = const [],
  BukuSvs? svs,
  DateTime? dari,
  DateTime? sampai,
}) => bandingkanImpor(
  backup: backup,
  svs: svs,
  konteks: const KonteksImpor(
    nota: [],
    profil: _profil,
    metodeBayar: _metode,
  ).denganNota(db),
  dari: dari ?? DateTime(2026, 10, 1),
  sampai: sampai ?? DateTime(2026, 10, 19),
);

extension on KonteksImpor {
  KonteksImpor denganNota(List<ServiceOrderEntry> n) => KonteksImpor(
    nota: n,
    profil: profil,
    metodeBayar: metodeBayar,
    jamTutup: jamTutup,
    libur: libur,
  );
}

Map<String, Object?> _set(BarisBanding b) => {
  for (final u in b.usulan) u.kolom: u.nilai,
};

BukuSvs _svs({
  Map<int, SvsMasuk> masuk = const {},
  Map<int, SvsKeluar> keluar = const {},
}) => BukuSvs(
  masuk: masuk,
  keluar: keluar,
  hari: [DateTime(2026, 10, 1), DateTime(2026, 10, 18)],
);

void main() {
  group('nota baru', () {
    test('masih di toko: ditambahkan sebagai masuk dengan teknisinya', () {
      final h = _banding([_bk(28794)]).single;
      expect(h.kategori, KategoriImpor.baru);
      expect(h.notaBaru!['status'], 'masuk');
      expect(h.notaBaru!['teknisi_id'], 'p-agus');
      expect(h.notaBaru!['no_nota'], 'SVR-16102628794');
      expect(h.notaBaru!['tanggal_diambil'], null);
    });

    test('cancel: batal, tanpa biaya, pada hari bukunya', () {
      final h = _banding([
        _bk(
          28795,
          status: 'batal',
          diambil: DateTime(2026, 10, 16),
          jam: '14:45:31',
        ),
      ]).single;
      expect(h.kategori, KategoriImpor.baru);
      expect(h.notaBaru!['status'], 'batal');
      expect(h.notaBaru!['biaya'], 0);
      expect(h.notaBaru!['cara_bayar'], null);
      expect(h.notaBaru!['tanggal_diambil'], '2026-10-16');
      expect(h.notaBaru!['tanggal_selesai'], '2026-10-16');
    });

    test('berbayar tanpa SVS: tidak ditambahkan, menunggu cara bayar', () {
      final h = _banding([
        _bk(
          28796,
          status: 'diambil',
          biaya: 200000,
          diambil: DateTime(2026, 10, 16),
          jam: '13:00:00',
        ),
      ]).single;
      expect(h.kategori, KategoriImpor.periksa);
      expect(h.perluCaraBayar, true);
      expect(h.notaBaru, null);
    });

    test('berbayar dengan SVS: cara bayar, perbaikan, dan nomor ikut buku', () {
      // Diterima Sabtu 17 Oktober; buku mencatatnya di lembar Jumat 16.
      final h = _banding(
        [
          _bk(
            28808,
            masuk: DateTime(2026, 10, 17),
            status: 'diambil',
            biaya: 100000,
            diambil: DateTime(2026, 10, 18),
            jam: '11:00:00',
          ),
        ],
        svs: _svs(
          masuk: {
            28808: SvsMasuk(
              urut: 28808,
              tanggal: DateTime(2026, 10, 16),
              nama: 'Akhsan',
              telp: '0822-5323-7884',
              barang: 'Ups Prolink',
              keluhan: 'Kadang Bunyi',
            ),
          },
          keluar: {
            28808: SvsKeluar(
              urut: 28808,
              tanggal: DateTime(2026, 10, 18),
              nama: 'Akhsan',
              perbaikan: 'Ganti Baterai',
              biaya: 100000,
              keterangan: 'QR BTN',
            ),
          },
        ),
      ).single;
      expect(h.kategori, KategoriImpor.baru);
      final n = h.notaBaru!;
      expect(n['no_nota'], 'SVR-16102628808');
      expect(n['tanggal_masuk'], '2026-10-16');
      expect(n['cara_bayar'], 'qris');
      expect(n['tanggal_lunas'], '2026-10-18');
      expect(n['perbaikan'], 'Ganti Baterai');
      expect(n['keluhan'], 'Kadang Bunyi', reason: 'keluhan mengikuti SVS');
      expect(n['customer_nama'], 'Akhsan');
    });
  });

  group('hari buku tanpa SVS: aturan jam tutup dan hari libur', () {
    String? hari(DateTime diambil, String jam) =>
        _banding([
              _bk(
                28800,
                status: 'diambil',
                garansi: true,
                diambil: diambil,
                jam: jam,
              ),
            ]).single.notaBaru!['tanggal_diambil']
            as String?;

    test('sebelum jam 17 tetap hari itu', () {
      expect(hari(DateTime(2026, 10, 16), '16:24:37'), '2026-10-16');
    });
    test('jam 17 atau sesudahnya masuk hari berikutnya', () {
      expect(hari(DateTime(2026, 10, 18), '17:18:48'), '2026-10-19');
    });
    test('Sabtu tidak punya lembar: pagi maupun malam jatuh ke Minggu', () {
      expect(hari(DateTime(2026, 10, 17), '10:00:00'), '2026-10-18');
      expect(hari(DateTime(2026, 10, 17), '19:26:58'), '2026-10-18');
    });
  });

  group('nota yang sudah ada', () {
    test('backup garansi, database masih masuk: koreksi lengkap', () {
      final h = _banding(
        [
          _bk(
            28433,
            masuk: DateTime(2026, 9, 18),
            status: 'diambil',
            garansi: true,
            diambil: DateTime(2026, 10, 16),
            jam: '11:49:57',
            teknisi: 'ADMIN',
          ),
        ],
        db: [_db(28433, masuk: DateTime(2026, 9, 18))],
      ).single;
      expect(h.kategori, KategoriImpor.koreksi);
      expect(_set(h), {
        'teknisi_id': 'p-admin',
        'status': 'diambil',
        'garansi': true,
        'tanggal_diambil': '2026-10-16',
        'tanggal_selesai': '2026-10-16',
      });
      expect(h.ubah!['id'], h.db!.id);
      expect(h.ubah!['updated_at'], '2026-10-15T11:54:38.096426Z');
    });

    test(
      'pekerjaan sudah selesai lebih dulu: tanggal selesainya dipertahankan',
      () {
        final h = _banding(
          [
            _bk(
              28618,
              masuk: DateTime(2026, 10, 4),
              status: 'batal',
              diambil: DateTime(2026, 10, 16),
              jam: '16:24:37',
            ),
          ],
          db: [
            _db(
              28618,
              masuk: DateTime(2026, 10, 4),
              status: 'selesai',
              selesai: DateTime(2026, 10, 10),
              garansi: true,
            ),
          ],
        ).single;
        final s = _set(h);
        expect(s['status'], 'batal');
        expect(s['tanggal_diambil'], '2026-10-16');
        expect(s.containsKey('tanggal_selesai'), false);
        expect(
          s.containsKey('garansi'),
          false,
          reason: 'batal tidak mencabut tanda garansi',
        );
      },
    );

    test(
      'sama-sama sudah keluar tanpa SVS: database dipercaya, tidak ada koreksi',
      () {
        final h = _banding(
          [
            _bk(
              28621,
              masuk: DateTime(2026, 10, 4),
              status: 'diambil',
              biaya: 100000,
              diambil: DateTime(2026, 10, 6),
              jam: '18:00:00',
            ),
          ],
          db: [
            _db(
              28621,
              masuk: DateTime(2026, 10, 4),
              status: 'diambil',
              biaya: 100000,
              cara: 'cash',
              lunas: DateTime(2026, 10, 7),
              diambil: DateTime(2026, 10, 7),
            ),
          ],
        ).single;
        expect(h.kategori, KategoriImpor.sama);
        expect(h.usulan, isEmpty);
      },
    );

    test('sudah keluar, SVS mencatat cara bayar lain: koreksi dari SVS', () {
      final svs = _svs(
        keluar: {
          28621: SvsKeluar(
            urut: 28621,
            tanggal: DateTime(2026, 10, 7),
            nama: 'X',
            biaya: 100000,
            keterangan: 'QR BTN',
          ),
        },
      );
      final h = _banding(
        [
          _bk(
            28621,
            masuk: DateTime(2026, 10, 4),
            status: 'diambil',
            biaya: 100000,
            diambil: DateTime(2026, 10, 6),
          ),
        ],
        db: [
          _db(
            28621,
            masuk: DateTime(2026, 10, 4),
            status: 'diambil',
            biaya: 100000,
            cara: 'cash',
            lunas: DateTime(2026, 10, 7),
            diambil: DateTime(2026, 10, 7),
          ),
        ],
        svs: svs,
      ).single;
      expect(h.kategori, KategoriImpor.koreksi);
      expect(_set(h), {'cara_bayar': 'qris'});
      expect(h.usulan.single.sumber, 'SVS');
    });

    test('QR BTN di aplikasi dan QRIS di SVS bukan perbedaan', () {
      final svs = _svs(
        keluar: {
          28621: SvsKeluar(
            urut: 28621,
            tanggal: DateTime(2026, 10, 7),
            nama: 'X',
            biaya: 100000,
            keterangan: 'QR BTN',
          ),
        },
      );
      final h = _banding(
        [
          _bk(
            28621,
            masuk: DateTime(2026, 10, 4),
            status: 'diambil',
            biaya: 100000,
            diambil: DateTime(2026, 10, 7),
          ),
        ],
        db: [
          _db(
            28621,
            masuk: DateTime(2026, 10, 4),
            status: 'diambil',
            biaya: 100000,
            cara: 'qr_btn',
            lunas: DateTime(2026, 10, 7),
            diambil: DateTime(2026, 10, 7),
          ),
        ],
        svs: svs,
      ).single;
      expect(h.kategori, KategoriImpor.sama);
    });

    test(
      'database sudah keluar, backup masih terbuka: tidak dibuka kembali',
      () {
        final h = _banding(
          [_bk(28700)],
          db: [_db(28700, status: 'diambil', diambil: DateTime(2026, 10, 12))],
        ).single;
        expect(h.kategori, KategoriImpor.periksa);
        expect(h.usulan, isEmpty);
        expect(h.catatan.single, contains('Tidak dibuka kembali'));
      },
    );

    test('berbayar tanpa SVS: teknisi tetap dikoreksi, status menunggu', () {
      final h = _banding(
        [
          _bk(
            28455,
            masuk: DateTime(2026, 9, 21),
            status: 'diambil',
            biaya: 200000,
            diambil: DateTime(2026, 10, 18),
            jam: '17:07:30',
            teknisi: 'BUDI',
          ),
        ],
        db: [_db(28455, masuk: DateTime(2026, 9, 21))],
      ).single;
      expect(h.kategori, KategoriImpor.koreksi);
      expect(_set(h), {'teknisi_id': 'p-budi'});
      expect(h.perluCaraBayar, true);
    });

    test('nota kembar di database: dilewati, tidak menebak', () {
      final h = _banding(
        [
          _bk(
            28433,
            masuk: DateTime(2026, 9, 19),
            status: 'diambil',
            garansi: true,
            diambil: DateTime(2026, 10, 16),
          ),
        ],
        db: [
          _db(28433, masuk: DateTime(2026, 9, 18)),
          _db(28433, masuk: DateTime(2026, 9, 19)),
        ],
      ).single;
      expect(h.kategori, KategoriImpor.periksa);
      expect(h.usulan, isEmpty);
      expect(h.catatan.single, contains('SVR-18092628433'));
    });

    test('nota Sabtu yang nomornya ikut lembar Jumat tetap dianggap sama', () {
      final h = _banding(
        [_bk(28610, masuk: DateTime(2026, 10, 3))],
        db: [_db(28610, masuk: DateTime(2026, 10, 2))],
      ).single;
      expect(h.kategori, KategoriImpor.sama);
      expect(h.catatan.single, contains('SVR-02102628610'));
    });

    test('nomor urut sama tetapi tanggal masuk jauh: tidak dibandingkan', () {
      final h = _banding(
        [_bk(28610, masuk: DateTime(2026, 10, 3))],
        db: [_db(28610, masuk: DateTime(2022, 4, 5))],
      ).single;
      expect(h.kategori, KategoriImpor.periksa);
      expect(h.usulan, isEmpty);
    });
  });

  group('data pelanggan dan keluhan', () {
    test('tanpa SVS: database dipertahankan walau backup berbeda', () {
      final h = _banding(
        [_bk(28700, nama: 'NAMA LAIN SAMA SEKALI', keluhan: 'KELUHAN LAIN')],
        db: [_db(28700)],
      ).single;
      expect(h.kategori, KategoriImpor.sama);
    });

    test(
      'dengan SVS: huruf besar-kecil bukan perbedaan, isi yang beda dikoreksi',
      () {
        final h = _banding(
          [_bk(28700)],
          db: [_db(28700, keluhan: 'Mati Total')],
          svs: _svs(
            masuk: {
              28700: SvsMasuk(
                urut: 28700,
                tanggal: DateTime(2026, 10, 16),
                nama: 'AKHSAN',
                telp: '082253237884',
                barang: 'UPS PROLINK',
                keluhan: 'Mati Total & Bunyi',
              ),
            },
          ),
        ).single;
        expect(h.kategori, KategoriImpor.koreksi);
        expect(_set(h), {'keluhan': 'Mati Total & Bunyi'});
      },
    );
  });

  group('teknisi', () {
    test(
      'nama yang belum terdaftar tidak mengubah apa pun dan diberi catatan',
      () {
        final h = _banding(
          [_bk(28700, teknisi: 'RICKY')],
          db: [_db(28700)],
        ).single;
        expect(h.usulan, isEmpty);
        expect(h.kategori, KategoriImpor.periksa);
        expect(h.catatan.single, contains('RICKY'));
      },
    );
    test('teknisi kosong di backup: penugasan lama dipertahankan', () {
      final h = _banding([_bk(28700, teknisi: '')], db: [_db(28700)]).single;
      expect(h.kategori, KategoriImpor.sama);
    });
  });

  group('rentang tanggal', () {
    test('nota lama yang keluar dalam rentang ikut dibandingkan', () {
      final hasil = _banding(
        [
          _bk(
            28333,
            masuk: DateTime(2026, 9, 13),
            status: 'diambil',
            garansi: true,
            diambil: DateTime(2026, 10, 18),
            jam: '17:18:48',
          ),
          _bk(28100, masuk: DateTime(2026, 8, 27)),
        ],
        db: [
          _db(28333, masuk: DateTime(2026, 9, 13)),
          _db(28100, masuk: DateTime(2026, 8, 27)),
        ],
        dari: DateTime(2026, 10, 16),
        sampai: DateTime(2026, 10, 18),
      );
      expect(hasil.map((h) => h.urut), [28333]);
      expect(_set(hasil.single)['tanggal_diambil'], '2026-10-19');
    });
  });
}
