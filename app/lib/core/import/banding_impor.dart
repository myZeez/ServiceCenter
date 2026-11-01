// Membandingkan isi backup aplikasi lama (dan buku SVS bila ada) dengan
// nota yang sudah ada di database, sebelum apa pun ditulis.
//
// Impor lama hanya menambah nota yang belum ada; nota yang sudah ada
// dianggap "sesuai" walau statusnya tertinggal. Di sini setiap nota di file
// dipilah menjadi baru, perlu koreksi, sama, atau perlu diperiksa, lengkap
// dengan kolom mana yang berbeda -- supaya data tidak asal ditumpuk.
//
// Siapa yang dipercaya untuk apa (keputusan Budi, 19 Oktober 2026):
//   backup  nota mana yang ada, teknisinya, dan apakah unit sudah keluar
//           sebagai garansi/cancel;
//   SVS     cara bayar, biaya, perbaikan, keluhan, data pelanggan, dan hari
//           bukunya;
//   database  dipertahankan bila SVS tidak ada. Backup tidak menimpa
//           keluhan atau data pelanggan, dan tidak pernah membuka lagi nota
//           yang sudah keluar.

import '../data/models.dart';
import '../hari_laporan.dart';
import 'svs_xlsx.dart';

enum KategoriImpor { baru, koreksi, sama, periksa }

/// Satu nota dari backup, hasil [parseLegacySql].
class NotaBackup {
  const NotaBackup({
    required this.urut,
    required this.noNota,
    required this.tanggalMasuk,
    required this.nama,
    this.telp,
    required this.barang,
    this.keluhan,
    this.kelengkapan,
    this.teknisi = '',
    required this.status,
    this.garansi = false,
    this.biaya = 0,
    this.tanggalDiambil,
    this.jamDiambil,
  });

  factory NotaBackup.fromMap(Map<String, dynamic> m) {
    DateTime? tgl(Object? v) => v == null ? null : DateTime.parse('$v');
    String? isi(Object? v) {
      final s = '${v ?? ''}'.trim();
      return s.isEmpty ? null : s;
    }

    final no = m['no_nota'] as String;
    return NotaBackup(
      urut: (m['urut'] as int?) ?? int.parse(no.substring(10)),
      noNota: no,
      tanggalMasuk: tgl(m['tanggal_masuk'])!,
      nama: '${m['customer_nama'] ?? ''}'.trim(),
      telp: isi(m['customer_telp']),
      barang: '${m['barang_nama'] ?? ''}'.trim(),
      keluhan: isi(m['keluhan']),
      kelengkapan: isi(m['kelengkapan']),
      teknisi: '${m['teknisi'] ?? ''}'.trim(),
      status: m['status'] as String,
      garansi: m['garansi'] == true,
      biaya: (m['biaya'] as num?)?.toDouble() ?? 0,
      tanggalDiambil: tgl(m['tanggal_diambil']),
      jamDiambil: isi(m['jam_diambil']),
    );
  }

  final int urut;
  final String noNota;
  final DateTime tanggalMasuk;
  final String nama;
  final String? telp;
  final String barang;
  final String? keluhan;
  final String? kelengkapan;
  final String teknisi;

  /// masuk, selesai, diambil, atau batal.
  final String status;
  final bool garansi;
  final double biaya;
  final DateTime? tanggalDiambil;
  final String? jamDiambil;

  bool get keluar => status == 'diambil' || status == 'batal';
}

/// Keadaan database dan pengaturan toko yang dibutuhkan pembanding.
class KonteksImpor {
  const KonteksImpor({
    required this.nota,
    required this.profil,
    required this.metodeBayar,
    this.jamTutup = jamTutupBawaan,
    this.libur = hariLiburBawaan,
  });

  final List<ServiceOrderEntry> nota;
  final List<Profile> profil;

  /// Kode metode bayar yang terdaftar.
  final Set<String> metodeBayar;
  final int jamTutup;
  final Set<int> libur;
}

/// Satu kolom yang diusulkan untuk dikoreksi.
class Usulan {
  const Usulan({
    required this.kolom,
    required this.label,
    required this.dari,
    required this.ke,
    required this.nilai,
    required this.sumber,
  });

  /// Nama kolom service_orders.
  final String kolom;
  final String label;

  /// Tampilan nilai di database dan nilai pengganti.
  final String dari;
  final String ke;

  /// Nilai yang dikirim ke server (teks, angka, boolean, tanggal ISO, atau
  /// null).
  final Object? nilai;

  /// 'backup' atau 'SVS'.
  final String sumber;
}

/// Hasil perbandingan satu nota.
class BarisBanding {
  const BarisBanding({
    required this.urut,
    required this.noNota,
    required this.nama,
    required this.kategori,
    this.db,
    this.usulan = const [],
    this.catatan = const [],
    this.notaBaru,
    this.perluCaraBayar = false,
  });

  final int urut;
  final String noNota;
  final String nama;
  final KategoriImpor kategori;

  /// Nota di database yang dibandingkan (kosong untuk nota baru).
  final ServiceOrderEntry? db;

  /// Koreksi yang bisa diterapkan.
  final List<Usulan> usulan;

  /// Keterangan yang tidak diterapkan: perbedaan yang dibiarkan, alasan
  /// sebuah nota dilewati.
  final List<String> catatan;

  /// Isi nota yang akan ditambahkan, untuk kategori baru.
  final Map<String, dynamic>? notaBaru;

  /// Unit sudah keluar dengan bayar, tetapi cara bayarnya tidak diketahui
  /// karena SVS-nya tidak disertakan atau tidak memuat nota ini.
  final bool perluCaraBayar;

  /// Yang dikirim ke server untuk nota yang sudah ada.
  Map<String, dynamic>? get ubah => db == null || usulan.isEmpty
      ? null
      : {
          'id': db!.id,
          'updated_at': db!.updatedAt.toUtc().toIso8601String(),
          'set': {for (final u in usulan) u.kolom: u.nilai},
        };
}

/// Nomor urut nota, sama dengan urut_no_nota() di server: angka mulai
/// huruf ke-11 dari nomor berbentuk AAA-DDMMYY#####.
int? urutNota(String noNota) =>
    RegExp(r'^[A-Za-z]{3}-[0-9]{11,}$').hasMatch(noNota)
    ? int.parse(noNota.substring(10))
    : null;

const _belumKeluar = {
  'masuk',
  'dikerjakan',
  'tunggu_part',
  'dikirim_cabang',
  'selesai',
};

/// Rentang bawaan begitu backup terbaca: bulan terakhir di berkas dan bulan
/// sebelumnya.
///
/// Mengikuti isi berkas, bukan kalender perangkat. Rentang "bulan berjalan"
/// membuat data akhir bulan tidak bisa diimpor begitu tanggalnya berganti:
/// tanggal 1 rentangnya hanya sehari, dan tanggal 31 tersaring habis. Bulan
/// sebelumnya selalu ikut karena perbandingan aman diulang -- nota yang sudah
/// sama tidak disentuh, jadi rentang yang lebih lebar tidak menumpuk apa pun.
///
/// Tanggal sesudah [kini] diabaikan: itu salah ketik di aplikasi lama.
({DateTime dari, DateTime sampai}) rentangBawaanImpor(
  List<NotaBackup> backup,
  DateTime kini,
) {
  final hariIni = _hari(kini);
  DateTime? terakhir;
  for (final b in backup) {
    for (final t in [b.tanggalMasuk, b.tanggalDiambil]) {
      if (t == null || t.isAfter(hariIni)) continue;
      if (terakhir == null || t.isAfter(terakhir)) terakhir = t;
    }
  }
  final sampai = terakhir == null ? hariIni : _hari(terakhir);
  return (dari: DateTime(sampai.year, sampai.month - 1), sampai: sampai);
}

/// Membandingkan nota [backup] yang masuk atau keluar dalam rentang
/// [dari]..[sampai] dengan database.
List<BarisBanding> bandingkanImpor({
  required List<NotaBackup> backup,
  BukuSvs? svs,
  required KonteksImpor konteks,
  required DateTime dari,
  required DateTime sampai,
}) {
  final awal = _hari(dari), akhir = _hari(sampai);
  bool dalam(DateTime? d) =>
      d != null && !_hari(d).isBefore(awal) && !_hari(d).isAfter(akhir);

  final perUrut = <int, List<ServiceOrderEntry>>{};
  for (final n in konteks.nota) {
    final u = urutNota(n.noNota);
    if (u != null) (perUrut[u] ??= []).add(n);
  }
  final idTeknisi = <String, List<String>>{};
  final namaProfil = <String, String>{};
  for (final p in konteks.profil) {
    (idTeknisi[p.nama.trim().toLowerCase()] ??= []).add(p.id);
    namaProfil[p.id] = p.nama;
  }

  final hasil = <BarisBanding>[];
  for (final b in backup) {
    final ctx = _Nota(
      b,
      svs?.masuk[b.urut],
      svs?.keluar[b.urut],
      konteks,
      idTeknisi,
    );
    // Hari buku ikut menentukan: unit yang diambil Sabtu malam 31 Oktober
    // tercatat di laporan 1 November, dan rentang 1 November harus
    // menemukannya walau tanggal kalendernya masih bulan lalu.
    if (!dalam(b.tanggalMasuk) &&
        !dalam(b.tanggalDiambil) &&
        !dalam(ctx.hariKeluar)) {
      continue;
    }
    final cocok = perUrut[b.urut] ?? const [];
    hasil.add(switch (cocok.length) {
      0 => ctx.baru(),
      // Nomor urut yang sama tetapi tanggal masuknya berjauhan bukan nota
      // yang sama -- kemungkinan nomor dari tahun lain. Selisih sehari
      // wajar: unit yang diterima Sabtu tercatat di lembar Jumat.
      1
          when _hari(cocok.single.tanggalMasuk.toLocal())
                  .difference(_hari(b.tanggalMasuk))
                  .inDays
                  .abs() >
              7 =>
        BarisBanding(
          urut: b.urut,
          noNota: b.noNota,
          nama: b.nama,
          kategori: KategoriImpor.periksa,
          db: cocok.single,
          catatan: [
            'Nomor urut ${b.urut} di database milik ${cocok.single.noNota}, '
                'yang tanggal masuknya jauh berbeda. Tidak dibandingkan.',
          ],
        ),
      1 => ctx.ada(cocok.single, namaProfil),
      _ => BarisBanding(
        urut: b.urut,
        noNota: b.noNota,
        nama: b.nama,
        kategori: KategoriImpor.periksa,
        catatan: [
          'Nomor urut ${b.urut} dipakai ${cocok.length} nota di database '
              '(${cocok.map((n) => n.noNota).join(', ')}). Dilewati; '
              'pilih nota resminya lebih dulu.',
        ],
      ),
    });
  }
  hasil.sort((a, b) => a.urut.compareTo(b.urut));
  return hasil;
}

class _Nota {
  _Nota(this.b, this.masuk, this.keluar, this.k, this.idTeknisi);

  final NotaBackup b;
  final SvsMasuk? masuk;
  final SvsKeluar? keluar;
  final KonteksImpor k;
  final Map<String, List<String>> idTeknisi;
  final catatan = <String>[];

  /// Unit sudah diserahkan. Buku SVS mencatat pengambilan, jadi nota yang
  /// ada di tabel keluarnya dianggap keluar walau backup belum menyusul.
  bool get unitKeluar => b.keluar || keluar != null;

  /// Hari buku unit keluar. Buku SVS menang; tanpa SVS, saat penyerahan di
  /// backup digeser dengan aturan jam tutup yang sama dengan server.
  DateTime? get hariKeluar {
    if (keluar != null) return keluar!.tanggal;
    final t = b.tanggalDiambil;
    if (t == null) return null;
    final jam = (b.jamDiambil ?? '12:00:00').split(':').map(int.parse).toList();
    return hariLaporan(
      DateTime(t.year, t.month, t.day, jam[0], jam.length > 1 ? jam[1] : 0),
      k.jamTutup,
      k.libur,
    );
  }

  /// Arti keluarnya unit: dari SVS bila ada, dari penanda backup bila tidak.
  /// Null berarti unit keluar dengan bayar tetapi cara bayarnya tidak
  /// diketahui.
  NasibKeluar? get nasib {
    if (keluar != null) {
      final n = nasibKeluarSvs(keluar!.keterangan, keluar!.biaya);
      final kataBackup = b.status == 'batal'
          ? 'cancel'
          : b.garansi
          ? 'garansi'
          : null;
      final kataSvs = n.status == 'batal'
          ? 'cancel'
          : n.garansi
          ? 'garansi'
          : null;
      if (kataBackup != kataSvs) {
        catatan.add(
          'Backup: ${kataBackup ?? 'berbayar'}, SVS: ${kataSvs ?? 'berbayar'} '
          '-- mengikuti SVS.',
        );
      }
      return n;
    }
    if (b.status == 'batal') {
      return const NasibKeluar(
        status: 'batal',
        garansi: false,
        biaya: 0,
        lunas: false,
      );
    }
    if (b.garansi) {
      return const NasibKeluar(
        status: 'diambil',
        garansi: true,
        biaya: 0,
        lunas: false,
      );
    }
    if (b.biaya == 0) {
      return const NasibKeluar(
        status: 'diambil',
        garansi: false,
        biaya: 0,
        lunas: false,
      );
    }
    return null;
  }

  String? get teknisiId {
    final nama = b.teknisi.toLowerCase();
    if (nama.isEmpty) return null;
    final id = idTeknisi[nama];
    if (id == null || id.length != 1) {
      catatan.add(
        id == null
            ? 'Teknisi "${b.teknisi}" belum terdaftar; teknisi tidak diubah.'
            : 'Nama teknisi "${b.teknisi}" dipakai beberapa akun; '
                  'teknisi tidak diubah.',
      );
      return null;
    }
    return id.single;
  }

  BarisBanding baru() {
    final n = unitKeluar ? nasib : null;
    final tekId = teknisiId;
    if (b.status == 'selesai' && !unitKeluar) {
      catatan.add(
        'Di backup sudah selesai dikerjakan; ditambahkan sebagai masuk karena '
        'tanggal selesainya tidak tercatat.',
      );
    }
    if (unitKeluar && n == null) {
      catatan.add(
        'Sudah diambil dengan bayar ${_rp(b.biaya)}, tetapi cara bayarnya '
        'hanya ada di SVS. Belum ditambahkan.',
      );
      return _hasil(KategoriImpor.periksa, perluCaraBayar: true);
    }
    if (n != null && _berbayar(n) && !k.metodeBayar.contains(n.caraBayar)) {
      catatan.add(
        'Cara bayar "${n.caraBayar}" belum terdaftar di Pengaturan. '
        'Belum ditambahkan.',
      );
      return _hasil(KategoriImpor.periksa, perluCaraBayar: true);
    }
    final m = masuk;
    // Nomor dan tanggal masuk mengikuti buku bila ada: unit yang diterima
    // Sabtu tercatat di lembar Jumat, dan nomor notanya ikut lembar itu.
    final tglMasuk = m?.tanggal ?? b.tanggalMasuk;
    final noNota = m == null
        ? b.noNota
        : 'SVR-${_dua(tglMasuk.day)}${_dua(tglMasuk.month)}'
              '${_dua(tglMasuk.year % 100)}${b.urut}';
    if (noNota != b.noNota) {
      catatan.add('Nomor mengikuti buku SVS: $noNota (backup ${b.noNota}).');
    }
    final hari = n == null ? null : hariKeluar;
    final bayar = n != null && _berbayar(n);
    final nota = <String, dynamic>{
      'no_nota': noNota,
      'tanggal_masuk': _iso(tglMasuk),
      'customer_nama': m?.nama ?? b.nama,
      'customer_telp': m?.telp ?? b.telp,
      'barang_nama': m?.barang ?? b.barang,
      'keluhan': m?.keluhan ?? b.keluhan,
      'kelengkapan': b.kelengkapan,
      'teknisi_id': tekId,
      'status': n?.status ?? 'masuk',
      'garansi': n?.garansi ?? false,
      'biaya': n?.biaya ?? 0,
      'cara_bayar': bayar ? n.caraBayar : null,
      'tanggal_lunas': bayar && n.lunas ? _iso(hari!) : null,
      'tanggal_selesai': hari == null ? null : _iso(hari),
      'tanggal_diambil': hari == null ? null : _iso(hari),
      'perbaikan': keluar?.perbaikan,
    };
    return _hasil(KategoriImpor.baru, notaBaru: nota);
  }

  BarisBanding ada(ServiceOrderEntry d, Map<String, String> namaProfil) {
    final usul = <Usulan>[];
    var perluBayar = false;

    if (d.noNota != b.noNota) {
      catatan.add('Nomor di database ${d.noNota} (backup ${b.noNota}).');
    }

    // Teknisi: backup yang menentukan; kosong di backup berarti biarkan.
    final tekId = teknisiId;
    if (tekId != null && tekId != d.teknisiId) {
      usul.add(
        Usulan(
          kolom: 'teknisi_id',
          label: 'Teknisi',
          dari: namaProfil[d.teknisiId] ?? '-',
          ke: namaProfil[tekId] ?? b.teknisi,
          nilai: tekId,
          sumber: 'backup',
        ),
      );
    }

    // Data pelanggan dan keluhan: hanya dari SVS. Tanpa SVS, database menang.
    final m = masuk;
    if (m != null) {
      void banding(String kolom, String label, String? lama, String? baru) {
        if (baru == null ||
            _sama(lama, baru, angka: kolom == 'customer_telp')) {
          return;
        }
        usul.add(
          Usulan(
            kolom: kolom,
            label: label,
            dari: lama ?? '-',
            ke: baru,
            nilai: baru,
            sumber: 'SVS',
          ),
        );
      }

      banding('customer_nama', 'Nama', d.customerNama, m.nama);
      banding('customer_telp', 'Telepon', d.customerTelp, m.telp);
      banding(
        'barang_nama',
        'Barang',
        [d.barangNama, d.barangType].whereType<String>().join(' '),
        m.barang,
      );
      banding('keluhan', 'Keluhan', d.keluhan, m.keluhan);
    }

    final dbKeluar = !_belumKeluar.contains(d.status);
    if (unitKeluar && !dbKeluar) {
      // Unit sudah diserahkan menurut backup, di database masih di toko.
      final n = nasib;
      if (n == null) {
        perluBayar = true;
        catatan.add(
          'Sudah diambil dengan bayar ${_rp(b.biaya)} menurut backup, tetapi '
          'cara bayarnya hanya ada di SVS. Status belum dikoreksi.',
        );
      } else if (_berbayar(n) && !k.metodeBayar.contains(n.caraBayar)) {
        perluBayar = true;
        catatan.add(
          'Cara bayar "${n.caraBayar}" belum terdaftar di Pengaturan. '
          'Status belum dikoreksi.',
        );
      } else {
        usul.addAll(_keluar(d, n, hariKeluar!, buka: true));
      }
    } else if (dbKeluar && keluar != null) {
      // Sama-sama sudah keluar: hanya SVS yang boleh membetulkan database.
      final n = nasib!;
      if (_berbayar(n) && !k.metodeBayar.contains(n.caraBayar)) {
        catatan.add('Cara bayar "${n.caraBayar}" di SVS belum terdaftar.');
      } else {
        usul.addAll(_keluar(d, n, keluar!.tanggal, buka: false));
      }
    } else if (!unitKeluar && dbKeluar) {
      catatan.add(
        'Di database sudah ${d.status}, di backup masih ${b.status}. '
        'Tidak dibuka kembali.',
      );
    }

    final kategori = usul.isNotEmpty
        ? KategoriImpor.koreksi
        : perluBayar || catatan.any((c) => !c.startsWith('Nomor di database'))
        ? KategoriImpor.periksa
        : KategoriImpor.sama;
    return BarisBanding(
      urut: b.urut,
      noNota: d.noNota,
      nama: d.customerNama,
      kategori: kategori,
      db: d,
      usulan: usul,
      catatan: List.unmodifiable(catatan),
      perluCaraBayar: perluBayar,
    );
  }

  /// Kolom yang berubah bila unit keluar dengan [n] pada [hari].
  ///
  /// [buka] berarti di database unit masih di toko: tanggal selesai diisi
  /// juga, kecuali pekerjaannya sudah tercatat selesai lebih dulu.
  List<Usulan> _keluar(
    ServiceOrderEntry d,
    NasibKeluar n,
    DateTime hari, {
    required bool buka,
  }) {
    final sumber = keluar != null ? 'SVS' : 'backup';
    final usul = <Usulan>[];
    void ubah(String kolom, String label, Object? lama, Object? baru) {
      final a = lama is DateTime ? _iso(lama) : lama;
      final z = baru is DateTime ? _iso(baru) : baru;
      if (a == z) return;
      usul.add(
        Usulan(
          kolom: kolom,
          label: label,
          dari: _tampil(kolom, a),
          ke: _tampil(kolom, z),
          nilai: z,
          sumber: sumber,
        ),
      );
    }

    ubah('status', 'Status', d.status, n.status);
    // Nota yang dibatalkan bisa saja nota klaim garansi; tandanya tidak
    // dicabut hanya karena unitnya batal.
    if (n.status != 'batal') ubah('garansi', 'Garansi', d.garansi, n.garansi);
    ubah('biaya', 'Biaya', d.biaya, n.biaya);
    if (_berbayar(n)) {
      if (!_caraSama(d.caraBayar, n.caraBayar)) {
        ubah('cara_bayar', 'Cara bayar', d.caraBayar, n.caraBayar);
      }
      ubah(
        'tanggal_lunas',
        'Tanggal lunas',
        d.tanggalLunas,
        n.lunas ? hari : null,
      );
    } else if (n.garansi || n.status == 'batal') {
      // Garansi dan batal tidak punya pembayaran.
      ubah('cara_bayar', 'Cara bayar', d.caraBayar, null);
      ubah('tanggal_lunas', 'Tanggal lunas', d.tanggalLunas, null);
    }
    // Nota Rp0 tanpa keterangan: catatan pembayarannya dibiarkan apa adanya.
    ubah('tanggal_diambil', 'Tanggal keluar', d.tanggalDiambil, hari);
    if (buka && (d.status != 'selesai' || d.tanggalSelesai == null)) {
      ubah('tanggal_selesai', 'Tanggal selesai', d.tanggalSelesai, hari);
    }
    final perbaikan = keluar?.perbaikan;
    if (perbaikan != null && !_sama(d.perbaikan, perbaikan)) {
      ubah('perbaikan', 'Perbaikan', d.perbaikan, perbaikan);
    }
    return usul;
  }

  BarisBanding _hasil(
    KategoriImpor kategori, {
    Map<String, dynamic>? notaBaru,
    bool perluCaraBayar = false,
  }) => BarisBanding(
    urut: b.urut,
    noNota: notaBaru?['no_nota'] as String? ?? b.noNota,
    nama: masuk?.nama ?? b.nama,
    kategori: kategori,
    catatan: List.unmodifiable(catatan),
    notaBaru: notaBaru,
    perluCaraBayar: perluCaraBayar,
  );
}

/// Unit keluar dengan uang berpindah tangan: ada biaya, bukan garansi dan
/// bukan batal.
bool _berbayar(NasibKeluar n) =>
    n.biaya > 0 && !n.garansi && n.status != 'batal';

/// QR BTN di buku SVS terbaca sebagai qris, tetapi aplikasi juga punya
/// metode qr_btn. Keduanya pembayaran QR yang sama; bukan perbedaan.
bool _caraSama(String? a, String? b) {
  String kelompok(String? k) => k == 'qr_btn' ? 'qris' : (k ?? '');
  return kelompok(a) == kelompok(b);
}

DateTime _hari(DateTime d) => DateTime(d.year, d.month, d.day);

String _dua(int n) => n.toString().padLeft(2, '0');

String _iso(DateTime d) => '${d.year}-${_dua(d.month)}-${_dua(d.day)}';

String _rp(double v) {
  final s = v.round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return 'Rp$buf';
}

String _tampil(String kolom, Object? v) {
  if (v == null) return '-';
  if (v is bool) return v ? 'ya' : 'tidak';
  if (kolom == 'biaya' && v is num) return _rp(v.toDouble());
  if (v is String && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v)) {
    return '${v.substring(8)}/${v.substring(5, 7)}/${v.substring(0, 4)}';
  }
  return '$v';
}

/// Sama bila isinya sama setelah huruf besar-kecil, spasi, dan tanda baca
/// diabaikan. "AKHSAN" dan "Akhsan" bukan perbedaan; buku SVS dan backup
/// memang menulis dengan gaya yang berbeda.
bool _sama(String? a, String? b, {bool angka = false}) {
  String bersih(String? s) => (s ?? '').toLowerCase().replaceAll(
    angka ? RegExp(r'\D') : RegExp(r'[^a-z0-9]'),
    '',
  );
  return bersih(a) == bersih(b);
}
