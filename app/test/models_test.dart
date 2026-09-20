// Pemetaan baris Postgres ke objek Dart. Salah satu nama kolom di sini
// tidak akan ketahuan saat analyze maupun saat aplikasi dibuka -- yang
// terjadi adalah layar kosong atau galat tipe di tengah pemakaian.
//
// Baris contohnya ditulis persis seperti yang dikirim PostgREST: angka
// numeric datang sebagai num, kolom date sebagai 'YYYY-MM-DD', dan kolom
// timestamptz lengkap dengan zona waktunya.

import 'package:flutter_test/flutter_test.dart';
import 'package:sc_management/core/data/models.dart';

void main() {
  group('Claim', () {
    test('membaca seluruh kolomnya', () {
      final c = Claim.fromMap({
        'id': 'abc',
        'tanggal': '2026-09-04T01:30:00+00:00',
        'brand_id': 3,
        'nama_pelanggan': 'Budi',
        'telp': '0812',
        'email': 'budi@mail.com',
        'sn': 'SN123',
        'teknisi_id': 'tek-1',
        'keluhan': 'Mati total',
        'no_perbaikan': 'IDD7R20024',
        'status': 'open',
        'catatan': null,
        'created_by': 'adm-1',
        'created_at': '2026-09-04T01:30:00+00:00',
        'updated_at': '2026-09-04T02:00:00+00:00',
      });

      expect(c.id, 'abc');
      expect(c.brandId, 3);
      expect(c.sn, 'SN123');
      expect(c.email, 'budi@mail.com');
      expect(c.catatan, isNull);
      // timestamptz dibawa ke waktu setempat: 01:30 UTC adalah 08:30 WIB,
      // dan yang dibaca orang di layar harus jam setempatnya.
      expect(c.tanggal.isUtc, isFalse);
      expect(c.tanggal.toUtc(), DateTime.utc(2026, 9, 4, 1, 30));
    });

    test('kolom opsional yang kosong tidak bikin gagal', () {
      final c = Claim.fromMap({
        'id': 'abc',
        'tanggal': '2026-09-04T00:00:00+00:00',
        'brand_id': 1,
        'nama_pelanggan': 'Budi',
        'telp': null,
        'sn': 'SN',
        'teknisi_id': null,
        'keluhan': null,
        'no_perbaikan': null,
        'status': 'open',
        'catatan': null,
        'created_by': 'adm',
        'created_at': '2026-09-04T00:00:00+00:00',
        'updated_at': '2026-09-04T00:00:00+00:00',
      });

      expect(c.telp, isNull);
      expect(c.email, isNull);
      expect(c.teknisiId, isNull);
      expect(c.noPerbaikan, isNull);
      expect(c.tanggalClose, isNull);
    });

    test('tanggal tutup dibaca sebagai tanggal kalender', () {
      final c = Claim.fromMap({
        'id': 'abc',
        'tanggal': '2026-03-28T23:00:00+00:00',
        'brand_id': 1,
        'nama_pelanggan': 'Budi',
        'telp': null,
        'sn': 'SN',
        'teknisi_id': null,
        'keluhan': null,
        'no_perbaikan': 'IDD7R20024',
        'status': 'close',
        'tanggal_close': '2026-04-02',
        'catatan': null,
        'created_by': 'adm',
        'created_at': '2026-03-28T23:00:00+00:00',
        'updated_at': '2026-04-02T09:00:00+00:00',
      });

      // Bukan titik waktu: menggesernya menurut zona waktu memindahkan unit
      // ini ke bulan rekap yang salah.
      expect(c.tanggalClose, DateTime(2026, 4, 2));
    });
  });

  group('ServiceOrderEntry', () {
    Map<String, dynamic> baris({
      Object? selesai = '2026-09-04',
      Object? biaya = 150000,
    }) => {
      'id': 'n1',
      'no_nota': 'SVR-04092628177',
      'tanggal_masuk': '2026-09-03T02:00:00+00:00',
      'estimasi_selesai': null,
      'customer_nama': 'Budi',
      'customer_telp': null,
      'customer_email': 'budi@mail.com',
      'customer_id': null,
      'operator_id': null,
      'barang_nama': 'Oppo',
      'barang_type': 'A16',
      'barang_sn': null,
      'kelengkapan': null,
      'keluhan': 'Mati total',
      'teknisi_id': null,
      'perbaikan': null,
      'garansi': false,
      'claim_id': null,
      'status': 'selesai',
      'biaya': biaya,
      'cara_bayar': null,
      'tanggal_lunas': null,
      'tanggal_selesai': selesai,
      'keterangan': null,
      'updated_at': '2026-09-04T02:00:00+00:00',
    };

    test('membaca seluruh kolomnya', () {
      final n = ServiceOrderEntry.fromMap(baris());
      expect(n.noNota, 'SVR-04092628177');
      expect(n.barangType, 'A16');
      expect(n.customerEmail, 'budi@mail.com');
      expect(n.garansi, isFalse);
      expect(n.biaya, 150000);
    });

    test('tanggal selesai tidak digeser zona waktu', () {
      // Kolomnya bertipe date, bukan titik waktu. Kalau digeser, nota yang
      // selesai tanggal 4 bisa terbaca tanggal 3 di laporan harian -- dan
      // laporan itu yang dikirim ke pusat.
      final n = ServiceOrderEntry.fromMap(baris());
      expect(n.tanggalSelesai, DateTime(2026, 9, 4));
    });

    test('nota yang belum selesai tanggalnya kosong', () {
      final n = ServiceOrderEntry.fromMap(baris(selesai: null));
      expect(n.tanggalSelesai, isNull);
    });

    test('biaya numeric dari Postgres dibaca sebagai pecahan', () {
      // PostgREST mengirim numeric sebagai num, bukan double. Tanpa
      // konversi, penjumlahan di laporan melempar galat tipe.
      final n = ServiceOrderEntry.fromMap(baris(biaya: 99500));
      expect(n.biaya, isA<double>());
      expect(n.biaya, 99500.0);
    });
  });

  group('Baris pengaturan', () {
    test('persentase numeric jadi pecahan', () {
      final r = RevenueConfig.fromMap({
        'id': 1,
        'persen_toko': 30,
        'persen_admin': 10,
        'persen_teknisi': 60,
        'metode_teknisi': 'per_unit',
      });
      expect(r.persenToko + r.persenAdmin + r.persenTeknisi, 100.0);
      expect(r.metodeTeknisi, 'per_unit');
    });

    test('fee brand memakai tanggal berlaku apa adanya', () {
      final f = BrandFeeEntry.fromMap({
        'id': 1,
        'brand_id': 2,
        'fee': 75000,
        'berlaku_dari': '2026-01-01',
      });
      expect(f.fee, 75000.0);
      expect(f.berlakuDari, DateTime(2026, 1, 1));
    });

    test('hasil pencocokan tanpa fee berarti memakai nilai awal', () {
      final s = ClaimSettlement.fromMap({
        'claim_id': 'k1',
        'fee': null,
        'cocok': true,
        'catatan': null,
        'updated_at': '2026-09-04T02:00:00+00:00',
      });

      // Kosong bukan nol. Nol berarti brand memang tidak membayar unit ini,
      // dan keduanya harus bisa dibedakan.
      expect(s.fee, isNull);
      expect(s.cocok, isTrue);
    });

    test('hasil pencocokan membawa angka dari surat brand', () {
      final s = ClaimSettlement.fromMap({
        'claim_id': 'k1',
        'fee': 125000,
        'cocok': true,
        'catatan': 'selisih 25rb dari nilai awal',
        'updated_at': '2026-09-04T02:00:00+00:00',
      });

      expect(s.claimId, 'k1');
      expect(s.fee, 125000.0);
      expect(s.catatan, 'selisih 25rb dari nilai awal');
    });

    test('porsi per brand dibaca dengan kunci gabungannya', () {
      final s = BrandShareEntry.fromMap({
        'brand_id': 2,
        'profile_id': 'tek-1',
        'persen': 40,
      });
      expect(s.brandId, 2);
      expect(s.profileId, 'tek-1');
      expect(s.persen, 40.0);
    });
  });

  group('Master', () {
    test('aktif yang tidak dikirim server dianggap aktif', () {
      expect(Brand.fromMap({'id': 1, 'nama': 'ASUS'}).aktif, isTrue);
      expect(
        PartType.fromMap({'id': 1, 'kode': 'MB', 'nama': 'Mainboard'}).aktif,
        isTrue,
      );
    });

    test('pelanggan membawa kode dan tanggal ubahnya', () {
      final c = CustomerEntry.fromMap({
        'id': 'p1',
        'kode': 'PLG0001',
        'nama': 'Budi',
        'telp': '0812',
        'alamat': null,
        'catatan': null,
        'updated_at': '2026-09-04T02:00:00+00:00',
      });
      expect(c.kode, 'PLG0001');
      expect(c.alamat, isNull);
    });
  });

  group('PartOrder', () {
    test('membaca seluruh kolomnya', () {
      final p = PartOrder.fromMap({
        'id': 'po1',
        'tanggal': '2026-09-04T01:30:00+00:00',
        'customer_nama': 'Jamal',
        'customer_telp': '0812',
        'customer_id': 'plg1',
        'barang_type': 'ASUS X441',
        'barang_sn': 'SN123',
        'part_req': 'KEYBOARD',
        'keterangan': 'oem',
        'teknisi_id': 'tek-1',
        'stok': 'ready',
        'tahap': 'dipesan',
        'harga': 120000,
        'dp': 50000,
        'sisa': 70000,
        'tanggal_selesai': null,
        'service_order_id': null,
        'catatan': null,
        'updated_at': '2026-09-04T02:00:00+00:00',
      });

      expect(p.partReq, 'KEYBOARD');
      expect(p.harga, 120000);
      expect(p.sisa, 70000);
      expect(p.tahap, 'dipesan');
    });

    test('harga yang belum diisi tetap null, bukan nol', () {
      // Nol berarti gratis; null berarti partnya masih dicari. Menyamakan
      // keduanya membuat baris yang belum berharga tampak sudah berharga.
      final p = PartOrder.fromMap({
        'id': 'po1',
        'tanggal': '2026-09-04T01:30:00+00:00',
        'customer_nama': 'Jamal',
        'part_req': 'LCD',
        'tahap': 'tanya',
        'harga': null,
        'dp': 0,
        'sisa': 0,
        'updated_at': '2026-09-04T02:00:00+00:00',
      });

      expect(p.harga, isNull);
      expect(p.dp, 0);
    });
  });

  group('PartCost', () {
    test('membaca modal dan persentasenya', () {
      final c = PartCost.fromMap({
        'part_order_id': 'po1',
        'hpp': 100000,
        'up_persen': 20,
      });
      expect(c.hpp, 100000);
      expect(c.upPersen, 20);
    });
  });

  group('PartSettingsRow', () {
    test('membaca larik JSON', () {
      final s = PartSettingsRow.fromMap({
        'up_toko_pilihan': [10, 15, 20],
        'up_toko_bawaan': 15,
      });
      expect(s.upTokoPilihan, [10, 15, 20]);
      expect(s.upTokoBawaan, 15);
    });

    test('membaca literal array Postgres', () {
      // Bentuk ini muncul di sebagian jalur. Kalau tidak diterima,
      // akibatnya bukan galat melainkan daftar pilihan yang diam-diam
      // kosong -- dan pengaturan yang tampak tidak pernah tersimpan.
      final s = PartSettingsRow.fromMap({
        'up_toko_pilihan': '{10.00,15.00,20.00}',
        'up_toko_bawaan': '10.00',
      });
      expect(s.upTokoPilihan, [10, 15, 20]);
      expect(s.upTokoBawaan, 10);
    });

    test('larik kosong tidak menjatuhkan apa pun', () {
      final s = PartSettingsRow.fromMap({
        'up_toko_pilihan': const <dynamic>[],
        'up_toko_bawaan': 10,
      });
      expect(s.upTokoPilihan, isEmpty);
    });
  });

  // Hari libur datang dari Postgres sebagai array. Bentuk kiriman bisa
  // dua rupa -- larik JSON atau literal '{6}' -- dan yang tidak terbaca
  // tidak menghasilkan galat, melainkan toko yang dianggap buka tiap hari.
  group('StoreSetting', () {
    StoreSetting baca(Object? hariLibur) => StoreSetting.fromMap({
      'id': 1,
      'nama': 'Cellcom',
      'tutup_jam': 17,
      'hari_libur': hariLibur,
    });

    test('membaca larik angka', () {
      expect(baca([6]).hariLibur, {DateTime.saturday});
      expect(baca([6, 7]).hariLibur, {DateTime.saturday, DateTime.sunday});
    });

    test('membaca literal array Postgres', () {
      expect(baca('{6}').hariLibur, {DateTime.saturday});
      expect(baca('{6,7}').hariLibur, {DateTime.saturday, DateTime.sunday});
    });

    test('daftar kosong berarti buka tiap hari', () {
      expect(baca(<Object?>[]).hariLibur, isEmpty);
      expect(baca('{}').hariLibur, isEmpty);
    });

    // Aplikasi yang lebih baru dari databasenya tidak boleh gagal membaca:
    // ia memakai bawaan yang sama dengan bawaan servernya.
    test('kolomnya belum ada: Sabtu, sama dengan bawaan server', () {
      final s = StoreSetting.fromMap({'id': 1, 'nama': 'Cellcom'});
      expect(s.hariLibur, {DateTime.saturday});
      expect(s.tutupJam, 17);
    });
  });
}
