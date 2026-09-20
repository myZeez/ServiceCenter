import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/data/models.dart';
import '../../core/print/nota_template.dart';
import '../../core/print/raw_printer.dart';
import '../../core/data/galat.dart';
import '../../core/status.dart';
import '../../core/fitur.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/swiss_widgets.dart';
import '../parts/part_dialog.dart';
import '../scan/scan_page.dart';
import 'antrian_teknisi.dart';
import 'customer_field.dart';
import 'kirim_cabang_fields.dart';
import 'service_status.dart';

const _uuid = Uuid();
final _rp = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp',
  decimalDigits: 0,
);
final _tglFmt = DateFormat('dd MMM yyyy');
final _tglJamFmt = DateFormat('dd MMM yyyy · HH:mm');
final _iso = DateFormat('yyyy-MM-dd');

Future<void> showServiceDialog(
  BuildContext context, {
  ServiceOrderEntry? nota,
}) {
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

/// Apakah biaya pada sebuah nota bergaransi perlu ditanyakan lebih dulu.
///
/// Aturan di toko: unit bergaransi tidak dikenakan biaya sama sekali --
/// perbaikannya ditanggung brand. Yang berbayar hanya layanan tambahan di
/// luar garansi, dan itu jarang. Jadi angka yang muncul pada nota
/// bergaransi hampir selalu salah ketik, bukan keputusan.
///
/// Bertanya, bukan menolak. Layanan tambahan memang ada, dan aturan yang
/// mengunci akan memaksa admin mencatatnya di tempat lain -- yang berarti
/// uang yang benar-benar masuk tidak terbaca di laporan mana pun.
///
/// Hanya saat angkanya berubah. Ditanyakan tiap kali nota yang sama
/// disimpan, pertanyaan ini berubah jadi tombol yang ditekan tanpa dibaca,
/// dan sesudah itu ia tidak menjaga apa-apa lagi.
bool perluKonfirmasiBiayaGaransi({
  required bool garansi,
  required double biaya,
  required double biayaLama,
}) => garansi && biaya > 0 && biaya != biayaLama;

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
  final _email = TextEditingController();
  final _barang = TextEditingController();
  final _type = TextEditingController();
  final _sn = TextEditingController();
  final _kelengkapan = TextEditingController();
  final _keluhan = TextEditingController();
  final _perbaikan = TextEditingController();
  final _biaya = TextEditingController();
  final _keterangan = TextEditingController();
  final _partReq = TextEditingController();

  /// Keluhan garansi -- milik KLAIMNYA, bukan nota ini. Hanya tampil pada
  /// nota garansi brand. Lihat [_kolomKeluhanGaransi].
  final _keluhanGaransi = TextEditingController();

  /// Klaim yang isinya sudah dimuat ke [_keluhanGaransi]. Diisi sekali saat
  /// klaimnya pertama kali tersedia; sesudah itu yang diketik tidak
  /// ditimpa kabar dari server.
  String? _keluhanGaransiDari;

  final _namaFokus = FocusNode();

  /// Pelanggan lama yang tertaut. Null berarti akan dibuatkan yang baru.
  CustomerEntry? _pelanggan;

  String? _teknisiId;
  int? _brandId;
  DateTime? _estimasi;
  bool _garansi = false;

  /// Jenis klaim yang akan lahir dari nota ini. Hanya berlaku saat
  /// centang garansi menyala dan klaimnya memang belum ada.
  String _jenisGaransi = ClaimJenis.brand;

  /// Apakah nota baru ini sekalian membuka tanya harga part.
  ///
  /// Selama tidak dicentang, formulir ini bekerja persis seperti sebelum
  /// ada fitur tanya harga -- tidak ada kolom tambahan yang wajib, dan
  /// tidak ada baris lain yang ikut dibuat.
  bool _tanyaHarga = false;
  String? _partKeterangan;
  String? _partBaru;
  String? _claimBaru;
  String _status = ServiceStatus.masuk;
  String? _caraBayar;
  DateTime? _tanggalLunas;

  /// Ke mana unit dikirim, dan kapan -- hanya dipakai saat statusnya
  /// Dikirim ke Cabang. Tanggalnya terisi hari ini sejak awal; ia baru
  /// diambil dari nota kalau nota itu memang sedang dalam pengiriman.
  String? _cabang;
  DateTime _tanggalKirim = hariIniKalender();

  /// Jawaban atas "apakah pembatalan ini berbiaya?". Null berarti belum
  /// dijawab -- dan nota batal tidak bisa disimpan sebelum dijawab.
  ///
  /// Pembatalan bisa berbiaya (biaya cek, misalnya) dan bisa tidak. Kalau
  /// dibiarkan menebak dari kolom biaya, harga taksiran yang sudah terlanjur
  /// diisi sebelum unitnya batal terbaca sebagai tagihan yang harus dibayar.
  bool? _biayaBatal;

  /// Status klaim yang dipilih di formulir. Kosong berarti belum disentuh
  /// -- dan klaim yang tidak disentuh tidak ditulis, supaya perubahan dari
  /// layar lain selama formulir ini terbuka tidak tertimpa nilai lama.
  ///
  /// Hanya berlaku untuk nota garansi brand. Pada nota seperti itu status
  /// nota tidak dikirim sama sekali: server yang menurunkannya dari klaim
  /// (migrasi 0027). Mengirim keduanya berarti dua penulisan yang saling
  /// menimpa, dan yang kalah adalah status yang lebih rinci.
  String? _statusKlaim;

  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final n = widget.nota;
    if (n == null) return;

    _nama.text = n.customerNama;
    _telp.text = n.customerTelp ?? '';
    _email.text = n.customerEmail ?? '';
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
    _cabang = n.cabangTujuan;
    // Nota yang sudah batal: jawabannya dibaca dari biayanya, supaya yang
    // dibuka tampil apa adanya. Yang belum batal harus menjawab sendiri.
    if (n.status == ServiceStatus.batal) _biayaBatal = n.biaya > 0;
    if (n.status == ServiceStatus.dikirimCabang && n.tanggalKirim != null) {
      _tanggalKirim = n.tanggalKirim!;
    }
  }

  /// Status nota diganti. Memilih Dikirim ke Cabang dari status lain
  /// berarti unitnya dikirim SEKARANG, jadi tanggalnya kembali ke hari
  /// ini -- bukan tanggal pengiriman lama yang masih tersimpan sebagai
  /// jejak.
  void _gantiStatus(String baru) {
    setState(() {
      if (baru == ServiceStatus.dikirimCabang &&
          widget.nota?.status != ServiceStatus.dikirimCabang) {
        _tanggalKirim = hariIniKalender();
      }
      // Batal dari status lain: biayanya belum dijawab, dan harga taksiran
      // yang mungkin sudah terisi tidak boleh ikut terbaca sebagai tagihan.
      if (baru == ServiceStatus.batal && widget.nota?.status != baru) {
        _biayaBatal = null;
      }
      _status = baru;
    });
  }

  /// Menjawab biaya pembatalan.
  ///
  /// Tanpa biaya mengosongkan biaya, cara bayar, dan tanggal lunas -- tidak
  /// ada uang yang terlibat, dan sisa isian lama tidak boleh tertinggal di
  /// nota yang dibatalkan.
  void _pilihBiayaBatal(bool ada) {
    setState(() {
      _biayaBatal = ada;
      if (!ada) {
        _biaya.clear();
        _caraBayar = null;
        _tanggalLunas = null;
      }
    });
  }

  /// Biaya, cara bayar, dan tanggal lunas dikunci selama pembatalannya
  /// dinyatakan tanpa biaya.
  bool get _kunciBiaya =>
      _status == ServiceStatus.batal && _biayaBatal == false;

  @override
  void dispose() {
    for (final c in [
      _nama,
      _telp,
      _email,
      _barang,
      _type,
      _sn,
      _kelengkapan,
      _keluhan,
      _perbaikan,
      _biaya,
      _keterangan,
      _partReq,
      _keluhanGaransi,
    ]) {
      c.dispose();
    }
    _namaFokus.dispose();
    super.dispose();
  }

  String? _kosongNull(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  /// Apakah tanda garansi pada nota ini masih boleh dinyalakan.
  ///
  /// Dua keadaan menutupnya, dan alasannya berbeda:
  ///
  ///   klaimnya sudah ada     melepasnya meninggalkan klaim yatim di
  ///                          halaman Klaim
  ///   sudah bertanda garansi tetapi tanpa klaim -- ini bentuk nota
  ///                          bergaransi di arsip 2026, yang klaimnya
  ///                          memang dicatat terpisah. Membiarkannya
  ///                          terbuka membuat sekadar membuka lalu
  ///                          menyimpan nota lama menerbitkan klaim baru
  ///                          yang tidak diminta siapa pun.
  bool get _bolehUbahGaransi =>
      widget.nota == null ||
      (!widget.nota!.garansi && widget.nota!.claimId == null);

  /// Apakah nomor seri wajib diisi pada nota ini.
  ///
  /// Hanya saat sebuah klaim KE BRAND memang akan lahir dari sini. Brand
  /// mengenali unit dari nomor serinya, dan klaim tanpa itu tidak bisa
  /// diproses siapa pun -- lebih baik ditolak saat diketik daripada
  /// ditemukan sebulan kemudian oleh orang di RC brand.
  bool get _perluSn =>
      _garansi && _bolehUbahGaransi && ClaimJenis.perluSn(_jenisGaransi);

  Future<bool> _biayaGaransiDisengaja(double biaya) async {
    if (!perluKonfirmasiBiayaGaransi(
      garansi: _garansi,
      biaya: biaya,
      biayaLama: widget.nota?.biaya ?? 0,
    )) {
      return true;
    }

    final lanjut = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Unit bergaransi, tetapi ada biaya'),
        content: Text(
          'Nota bergaransi biasanya tidak dikenakan biaya — perbaikannya '
          'ditanggung brand.\n\n'
          '${_rp.format(biaya)} ini hanya benar kalau memang ada layanan '
          'tambahan di luar garansi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(d).pop(false),
            child: const Text('PERIKSA LAGI'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(d).pop(true),
            child: const Text('ADA LAYANAN TAMBAHAN'),
          ),
        ],
      ),
    );

    return lanjut ?? false;
  }

  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) return;
    if (_garansi && _brandId == null && _bolehUbahGaransi) {
      setState(() => _error = 'Pilih brand untuk klaim garansinya.');
      return;
    }

    // Nota batal wajib menyatakan biayanya. Pada nota garansi brand statusnya
    // milik klaim, jadi aturannya tidak berlaku di sini.
    final atur =
        _status == ServiceStatus.batal &&
        ref.read(klaimBrandNotaProvider(widget.nota?.claimId)) == null;
    if (atur) {
      final jumlah = double.tryParse(_biaya.text) ?? 0;
      final galat = switch (_biayaBatal) {
        null => 'Tentukan biaya pembatalan: tanpa biaya, atau ada biaya.',
        true when jumlah <= 0 =>
          'Pembatalan berbiaya harus mengisi jumlah biayanya. Kalau tidak '
              'ada biaya, pilih Tanpa Biaya.',
        true when _caraBayar == null =>
          'Pilih cara bayar biaya pembatalan. Kalau belum dibayar, pilih '
              'cara bayar yang berstatus piutang.',
        _ => null,
      };
      if (galat != null) {
        setState(() => _error = galat);
        return;
      }
    }
    if (!await _biayaGaransiDisengaja(double.tryParse(_biaya.text) ?? 0)) {
      return;
    }
    if (!mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    final client = ref.read(supabaseProvider);
    final user = ref.read(currentUserProvider);

    try {
      // Kartu pelanggan hanya diterbitkan untuk nota BARU.
      //
      // Nota yang sudah ada memuat nama dan teleponnya sebagai teks, dan
      // itu salinan yang disengaja: nota yang sudah tercetak harus tetap
      // cocok dengan kertasnya walau data pelanggannya berubah kemudian.
      // Menyimpannya lagi tidak perlu menerbitkan kartu siapa pun.
      //
      // Dulu syarat ini tidak ada, dan akibatnya keras: 3.085 nota hasil
      // impor arsip sengaja tidak punya kartu pelanggan sama sekali, jadi
      // SETIAP kali salah satunya disunting -- sekadar mengubah status --
      // satu kartu pelanggan kembar lahir tanpa ada yang memintanya, dan
      // notanya berpindah menunjuk ke kartu baru itu.
      //
      // Yang sudah tertaut tetap tidak disentuh: mengubah data master
      // dari formulir nota berarti satu koreksi ketik diam-diam mengubah
      // riwayat pelanggan lain yang bernama sama.
      var customerId = _pelanggan?.id ?? widget.nota?.customerId;
      if (customerId == null && widget.isNew) {
        final baru = await client
            .from('customers')
            .insert({'nama': _nama.text.trim(), 'telp': _kosongNull(_telp)})
            .select()
            .single();
        customerId = baru['id'] as String;
      }

      String? claimId = widget.nota?.claimId;

      // Unit bergaransi menghasilkan dua catatan sekaligus: nota untuk
      // pelanggan, dan klaim untuk brand. Datanya diketik satu kali.
      final perluKlaim = _garansi && claimId == null && _bolehUbahGaransi;

      // Dibuat sekali lalu dipakai lagi kalau penyimpanannya diulang.
      // Klaimnya bisa saja sudah sampai server sebelum notanya gagal
      // tersimpan; dengan id yang sama, percobaan berikutnya menyunting
      // klaim yang itu juga alih-alih menerbitkan klaim kembar.
      if (perluKlaim) claimId = _claimBaru ??= _uuid.v4();

      Map<String, dynamic> isiKlaim() => {
        'id': claimId,
        // Tanggal masuk unitnya, bukan tanggal orang menyadarinya
        // bergaransi. Yang dijawab kolom ini adalah kapan unit ini
        // sampai di meja.
        'tanggal': (widget.nota?.tanggalMasuk ?? DateTime.now())
            .toUtc()
            .toIso8601String(),
        'brand_id': _brandId!,
        'jenis': _jenisGaransi,
        'nama_pelanggan': _nama.text.trim(),
        'telp': _kosongNull(_telp),
        'email': _kosongNull(_email),
        'sn': _sn.text.trim(),
        'teknisi_id': _teknisiId,
        // Keluhan klaim sengaja TIDAK disalin dari nota. Yang di nota
        // adalah kata-kata pelanggan saat unit datang; yang di klaim
        // adalah hasil pengecekan teknisi, dan itu yang dibaca brand.
        // Menyalinnya membuat laporan garansi berisi "mati tiba-tiba"
        // sampai ada yang ingat menggantinya.
        'status': 'open',
        'created_by': user!.id,
      };

      // Pada nota baru, klaimnya disimpan lebih dulu: notanya menunjuk ke
      // baris ini, dan server menolak tautan ke baris yang belum ada.
      if (perluKlaim && widget.isNew) {
        await ref.read(databaseProvider).simpanClaim(isiKlaim());
      }

      final klaimBrand = ref.read(klaimBrandNotaProvider(widget.nota?.claimId));

      final data = {
        'estimasi_selesai': _estimasi == null ? null : _iso.format(_estimasi!),
        'customer_nama': _nama.text.trim(),
        'customer_telp': _kosongNull(_telp),
        'customer_email': _kosongNull(_email),
        'customer_id': customerId,
        'operator_id': user?.id,
        'barang_nama': _barang.text.trim(),
        'barang_type': _kosongNull(_type),
        'barang_sn': _kosongNull(_sn),
        'kelengkapan': _kosongNull(_kelengkapan),
        'keluhan': _kosongNull(_keluhan),
        'teknisi_id': _teknisiId,
        'perbaikan': _kosongNull(_perbaikan),
        // Pada nota yang sudah ada, tanda garansi sengaja TIDAK lewat
        // sini. Penjaga kolom di server menolak siapa pun selain admin
        // mengubah dua kolom ini lewat update biasa; yang berhak
        // mengubahnya hanya tautkan_nota_ke_klaim() di bawah. Dikirim apa
        // adanya supaya nilainya tidak berbeda dari yang tersimpan --
        // penjaganya membandingkan nilai, bukan niat.
        'garansi': widget.isNew ? _garansi : widget.nota!.garansi,
        'claim_id': widget.isNew ? claimId : widget.nota!.claimId,
        if (klaimBrand == null) 'status': _status,
        // Cabang dan tanggal hanya ditulis saat statusnya memang Dikirim
        // ke Cabang. Di status lain dibiarkan seperti yang tersimpan --
        // itu jejak ke mana unitnya pernah dikirim.
        if (klaimBrand == null && _status == ServiceStatus.dikirimCabang) ...{
          'cabang_tujuan': _cabang,
          'tanggal_kirim': _iso.format(_tanggalKirim),
        },
        // Pembatalan tanpa biaya menulis nol, bukan apa pun yang tersisa di
        // kolomnya.
        'biaya': _kunciBiaya ? 0 : (double.tryParse(_biaya.text) ?? 0),
        'cara_bayar': _kunciBiaya ? null : _caraBayar,
        'tanggal_lunas': _kunciBiaya || _tanggalLunas == null
            ? null
            : _iso.format(_tanggalLunas!),
        'keterangan': _kosongNull(_keterangan),
      };

      String notaId;
      if (widget.isNew) {
        // Idnya diminta kembali karena tanya harga di bawah menunjuk ke
        // baris ini. Nomor notanya sendiri tetap ditetapkan server.
        final baru = await client
            .from('service_orders')
            .insert(data)
            .select('id')
            .single();
        notaId = baru['id'] as String;
      } else {
        notaId = widget.nota!.id;
        await client.from('service_orders').update(data).eq('id', notaId);
      }

      // Sesudah notanya, bukan sebelumnya: server menurunkan status nota
      // dari klaim ini, dan saat itu cara bayar yang baru saja diubah
      // harus sudah tersimpan -- dari situlah tanggal lunas distempel.
      if (klaimBrand != null) {
        final statusKlaim = _statusKlaim;
        final keluhanGaransi = _kosongNull(_keluhanGaransi);
        final perubahan = {
          if (statusKlaim != null && statusKlaim != klaimBrand.status)
            'status': statusKlaim,
          if (_keluhanGaransiDari == klaimBrand.id &&
              keluhanGaransi != klaimBrand.keluhan)
            'keluhan': keluhanGaransi,
        };
        if (perubahan.isNotEmpty) {
          await ref.read(databaseProvider).ubahClaim(klaimBrand.id, perubahan);
        }
      }

      // Nota yang ternyata bergaransi. Klaimnya lahir belakangan, lalu
      // ditautkan lewat fungsi khusus di server -- satu-satunya jalan
      // yang boleh menyentuh garansi dan claim_id.
      //
      // Kalau langkah ini gagal, dialognya tidak ditutup dan galatnya
      // tampil. Menekan simpan sekali lagi aman: idnya sudah dibuat dan
      // dipakai ulang, penyimpanan klaimnya berupa upsert, dan penautan
      // ke klaim yang sama tidak ditolak.
      if (perluKlaim && !widget.isNew) {
        final db = ref.read(databaseProvider);
        await db.simpanClaim(isiKlaim());
        await db.tautkanNotaKeKlaim(notaId, claimId!);
      }

      // Tanya harga lahir SESUDAH notanya: barisnya menunjuk ke nota itu,
      // dan server menolak tautan ke baris yang belum ada.
      var tanyaHargaGagal = false;
      if (widget.isNew && _tanyaHarga) {
        // Id dibuat sekali lalu dipakai lagi bila penyimpanannya diulang,
        // sama seperti klaim garansi di atas.
        final idPart = _partBaru ??= _uuid.v4();
        try {
          await ref.read(databaseProvider).simpanPartOrder({
            'id': idPart,
            'customer_nama': _nama.text.trim(),
            'customer_telp': _kosongNull(_telp),
            'customer_id': customerId,
            'barang_type': [
              _barang.text.trim(),
              _type.text.trim(),
            ].where((s) => s.isNotEmpty).join(' '),
            'barang_sn': _kosongNull(_sn),
            'part_req': _partReq.text.trim(),
            'keterangan': _partKeterangan,
            'teknisi_id': _teknisiId,
            'service_order_id': notaId,
            'created_by': user!.id,
          });
        } catch (_) {
          // Notanya sudah terlanjur tersimpan. Kalau kegagalan ini
          // dilaporkan seperti kegagalan biasa, admin akan menekan simpan
          // sekali lagi dan menerbitkan nota kedua -- membakar satu nomor
          // nota yang dibaca pusat. Jadi dialognya tetap ditutup, dan yang
          // dikabarkan persis apa yang terjadi.
          tanyaHargaGagal = true;
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tanyaHargaGagal
                ? 'Nota tersimpan, tetapi tanya harganya gagal dibuat. '
                      'Buat dari halaman Tanya Harga — jangan simpan nota '
                      'ini lagi.'
                : (widget.isNew ? 'Nota tersimpan' : 'Nota diperbarui'),
          ),
          duration: Duration(seconds: tanyaHargaGagal ? 10 : 4),
        ),
      );
    } on PostgrestException catch (e) {
      setState(() => _error = pesanGalat(e));
    } catch (_) {
      setState(
        () => _error =
            'Gagal menyimpan. Membuat nota membutuhkan koneksi, '
            'karena nomornya ditetapkan server agar tidak kembar.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Nota lapis dicetak sekali; karbon di lapis bawah yang menghasilkan
  /// salinannya. Mencetak dua kali justru memboroskan kertas.
  Future<void> _cetak(JenisNota jenis) async {
    final n = widget.nota;
    if (n == null) return;

    final printer = ref.read(printerNamaProvider).valueOrNull ?? '';
    final lebar = ref.read(printerLebarProvider).valueOrNull ?? 32;
    final toko = ref.read(storeSettingsProvider).valueOrNull;

    final orang = {
      for (final p
          in ref.read(techniciansProvider).valueOrNull ?? const <Profile>[])
        p.id: p.nama,
    };
    final semuaProfil = await ref.read(databaseProvider).allProfiles();
    final operator = semuaProfil
        .where((p) => p.id == n.operatorId)
        .map((p) => p.nama)
        .firstOrNull;

    final galat = RawPrinter.kirim(
      printer,
      susunNota(
        nota: n,
        jenis: jenis,
        toko: toko,
        namaTeknisi: orang[n.teknisiId],
        namaOperator: operator,
        namaCaraBayar: ref.read(namaMetodeBayar(n.caraBayar)),
        lebar: lebar,
      ),
    );

    if (!mounted) return;
    if (galat != null) {
      setState(() => _error = galat);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${jenis.judul} dikirim ke printer')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final techs = ref.watch(pengerjaUntukProvider(_teknisiId));
    final brands = ref.watch(brandsProvider).valueOrNull ?? const <Brand>[];
    final size = MediaQuery.sizeOf(context);

    // Nota yang sedang disunting mungkin sudah tertaut; tautannya dicari
    // sekali saat daftar pelanggan tersedia.
    final idTertaut = widget.nota?.customerId;
    if (_pelanggan == null && idTertaut != null) {
      final daftar = ref.watch(customersProvider).valueOrNull;
      if (daftar != null) {
        for (final c in daftar) {
          if (c.id == idTertaut) {
            _pelanggan = c;
            break;
          }
        }
      }
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Material(
          color: context.warna.permukaan,
          borderRadius: BorderRadius.circular(AppRadius.base),
          clipBehavior: Clip.antiAlias,
          child: Container(
            width: 1060,
            constraints: BoxConstraints(maxHeight: size.height - 80),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.base),
              border: Border.all(color: context.warna.garisHalus),
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
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: context.warna.teks, width: 1.5),
        ),
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
                      // Sampai jamnya, supaya lebih rinci.
                      : _tglJamFmt.format(n.tanggalMasuk),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          if (n != null) ...[
            StatusNotaChip(n),
            const SizedBox(width: AppSpacing.s),
          ],
          IconButton(
            iconSize: 18,
            color: context.warna.teksLembut,
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
        CustomerField(
          controller: _nama,
          focusNode: _namaFokus,
          pelanggan:
              ref.watch(customersProvider).valueOrNull ??
              const <CustomerEntry>[],
          terpilih: _pelanggan,
          onPilih: (c) => setState(() {
            _pelanggan = c;
            _nama.text = c.nama;
            if ((c.telp ?? '').isNotEmpty) _telp.text = c.telp!;
          }),
          onBaru: () => setState(() => _pelanggan = null),
          buatKartuBaru: widget.isNew,
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
          // Tidak pernah wajib, pada jenis garansi mana pun.
          //
          // Sempat dipaksa saat centang garansi menyala, dengan alasan
          // portal RMA brand menuntutnya. Alasannya benar tetapi tempatnya
          // salah: yang menuntut email adalah portal brand saat unitnya
          // didaftarkan ke sana, bukan meja depan saat notanya diketik.
          // Pelanggan yang tidak punya email -- atau tidak ingat -- tidak
          // boleh membuat notanya gagal disimpan.
          hint: _garansi && _bolehUbahGaransi
              ? 'Portal RMA sebagian brand menuntutnya. Boleh dikosongkan '
                    'dan diisi belakangan.'
              : null,
          child: TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(hintText: 'nama@email.com'),
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
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
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
          required: _perluSn,
          hint: _perluSn
              ? 'Brand mengenali unit dari nomor serinya. Klaim tanpa ini '
                    'tidak bisa diproses siapa pun.'
              : null,
          child: TextFormField(
            controller: _sn,
            textCapitalization: TextCapitalization.characters,
            // Wajib hanya saat unitnya diklaimkan KE BRAND. Servis biasa
            // sering masuk tanpa nomor seri terbaca -- stikernya sudah
            // hilang atau unitnya mati total -- dan itu tidak menghalangi
            // perbaikan. Garansi toko juga tidak memerlukannya: unitnya
            // baru saja ditangani toko sendiri, notanya masih ada, dan
            // tidak ada pihak luar yang perlu diyakinkan.
            validator: (v) => _perluSn && (v ?? '').trim().isEmpty
                ? 'Nomor seri wajib untuk klaim ke brand'
                : null,
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
    final metode = ref.watch(metodeBayarProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Servis'),
        const SizedBox(height: AppSpacing.s),
        LabeledField(
          label: 'Keluhan Pelanggan',
          hint: 'Yang disampaikan pelanggan saat unit datang.',
          child: TextFormField(
            controller: _keluhan,
            maxLines: 2,
            textCapitalization: TextCapitalization.characters,
          ),
        ),
        _kolomKeluhanGaransi(),
        const SizedBox(height: AppSpacing.s),

        // Antrian siapa yang sebaiknya diberi unit berikutnya. Hanya untuk
        // nota baru: yang sudah punya teknisi tidak sedang membagi kerja.
        if (widget.isNew) ...[
          AntrianTeknisiPanel(
            terpilih: _teknisiId,
            onPilih: (id) => setState(() => _teknisiId = id),
          ),
          const SizedBox(height: AppSpacing.s),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: LabeledField(
                label: 'Teknisi',
                hint: techs.isEmpty
                    ? 'Belum ada teknisi. Tambahkan di Pengaturan → Pengguna.'
                    : null,
                child: DropdownButtonFormField<String>(
                  // Dibangun ulang saat pilihannya berubah dari luar -- dari
                  // antrian di atasnya -- karena field ini hanya membaca
                  // initialValue sekali.
                  key: ValueKey('teknisi-$_teknisiId'),
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
                      initialDate:
                          _estimasi ??
                          DateTime.now().add(const Duration(days: 3)),
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 365),
                      ),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (p != null) setState(() => _estimasi = p);
                  },
                  style: _tombolTanggal(context),
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
        //
        // Tetap hidup setelah notanya tersimpan, dan itu bukan kelonggaran
        // melainkan urutan kerja yang sebenarnya: unit masuk sebagai
        // servis biasa, dibongkar, dan baru di situ ketahuan masih
        // bergaransi. Yang dikunci hanya nota yang klaimnya sudah ada --
        // melepasnya berarti meninggalkan klaim yatim di halaman Klaim.
        CheckboxListTile(
          value: _garansi,
          onChanged: _bolehUbahGaransi
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
            widget.nota?.claimId != null
                ? 'Klaimnya sudah dibuat. Buka di halaman Klaim untuk '
                      'mengubahnya.'
                : !_bolehUbahGaransi
                ? 'Sudah bertanda garansi. Klaimnya dicatat terpisah di '
                      'halaman Klaim.'
                : widget.isNew
                ? 'Klaimnya dibuat otomatis dari data ini. Pilih jenisnya '
                      'di bawah.'
                : 'Ternyata garansi setelah dicek? Centang saja — klaimnya '
                      'dibuat saat nota ini disimpan.',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
        if (_garansi && _bolehUbahGaransi) ...[
          const SizedBox(height: AppSpacing.xs),
          LabeledField(
            label: 'Jenis Garansi',
            required: true,
            hint: ClaimJenis.hint(_jenisGaransi),
            child: DropdownButtonFormField<String>(
              initialValue: _jenisGaransi,
              isExpanded: true,
              items: [
                for (final j in ClaimJenis.all)
                  DropdownMenuItem(value: j, child: Text(ClaimJenis.label(j))),
              ],
              onChanged: (v) =>
                  setState(() => _jenisGaransi = v ?? ClaimJenis.brand),
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          LabeledField(
            label: 'Brand untuk Klaim',
            required: true,
            // Diisi pada kedua jenis. Pada garansi toko bukan untuk
            // ditagihkan, melainkan supaya merek unit yang sering kembali
            // dalam masa garansi servis tetap bisa dihitung.
            hint: ClaimJenis.ditagihkan(_jenisGaransi)
                ? null
                : 'Tidak ditagihkan ke brand — hanya untuk mencatat merek '
                      'unitnya.',
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

        // Sedang disimpan -- lihat fiturTanyaHargaProvider.
        if (ref.watch(fiturTanyaHargaProvider)) ...[
          const SizedBox(height: AppSpacing.xs),
          _tanyaHargaBagian(context),
        ],

        const SizedBox(height: AppSpacing.sm),
        const SectionLabel('Penyelesaian'),
        const SizedBox(height: AppSpacing.s),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _kolomStatus()),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: LabeledField(
                label: 'Biaya',
                // Disebut di kolomnya, bukan cuma ditanyakan saat
                // menyimpan: yang paling murah adalah salah ketik yang
                // tidak jadi diketik.
                hint: _kunciBiaya
                    ? 'Pembatalan tanpa biaya.'
                    : _garansi
                    ? 'Unit bergaransi ditanggung brand — biasanya Rp0. '
                          'Isi hanya kalau ada layanan tambahan di luar '
                          'garansi.'
                    : null,
                child: TextFormField(
                  controller: _biaya,
                  enabled: !_kunciBiaya,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  // Dibaca ulang supaya keterangan dan pertanyaan di atas
                  // ikut menyala begitu angkanya diketik.
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(prefixText: 'Rp '),
                ),
              ),
            ),
          ],
        ),
        if (_status == ServiceStatus.batal &&
            ref.watch(klaimBrandNotaProvider(widget.nota?.claimId)) ==
                null) ...[
          const SizedBox(height: AppSpacing.s),
          _pilihanBiayaBatal(),
        ],
        if (_status == ServiceStatus.dikirimCabang &&
            ref.watch(klaimBrandNotaProvider(widget.nota?.claimId)) ==
                null) ...[
          const SizedBox(height: AppSpacing.s),
          KirimCabangFields(
            cabang: _cabang,
            tanggal: _tanggalKirim,
            onCabang: (v) => setState(() => _cabang = v),
            onTanggal: (d) => setState(() => _tanggalKirim = d),
          ),
        ],
        const SizedBox(height: AppSpacing.s),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: LabeledField(
                label: 'Cara Bayar',
                child: DropdownButtonFormField<String>(
                  // Dibangun ulang saat nilainya berubah dari luar -- pilihan
                  // Tanpa Biaya mengosongkannya, dan field ini hanya membaca
                  // initialValue sekali.
                  key: ValueKey('cara-$_caraBayar'),
                  // Cara bayar nota lama selalu ikut, walau metodenya
                  // sudah dinonaktifkan: dropdown yang nilainya tidak ada
                  // di antara pilihannya melempar galat, dan nota yang
                  // sudah tercetak harus tetap menyebut yang di kertasnya.
                  initialValue: metode.any((m) => m.kode == _caraBayar)
                      ? _caraBayar
                      : null,
                  isExpanded: true,
                  hint: Text(_caraBayar ?? '—'),
                  items: [
                    for (final m in metode)
                      DropdownMenuItem(value: m.kode, child: Text(m.nama)),
                  ],
                  onChanged: _kunciBiaya
                      ? null
                      : (v) => setState(() => _caraBayar = v),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: LabeledField(
                label: 'Tanggal Lunas',
                child: OutlinedButton(
                  onPressed: _kunciBiaya
                      ? null
                      : () async {
                          final p = await showDatePicker(
                            context: context,
                            initialDate: _tanggalLunas ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (p != null) setState(() => _tanggalLunas = p);
                        },
                  style: _tombolTanggal(context),
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
                            ? context.warna.bahaya
                            : context.warna.teks,
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

  /// Pembatalan berbiaya atau tanpa biaya -- wajib dijawab.
  ///
  /// Dua-duanya sah: unit yang dibatalkan setelah dicek bisa dikenai biaya
  /// cek, dan yang dibatalkan sebelum dibuka tidak. Yang tidak sah adalah
  /// tidak menjawab, karena Rp0 di laporan bisa berarti gratis dan bisa
  /// berarti belum ditentukan.
  Widget _pilihanBiayaBatal() {
    final w = context.warna;

    return LabeledField(
      label: 'Biaya Pembatalan',
      required: true,
      hint: switch (_biayaBatal) {
        null =>
          'Pembatalan bisa berbiaya (biaya cek, misalnya) dan bisa tidak. '
              'Tentukan dulu.',
        true => 'Isi jumlah biaya dan cara bayarnya di bawah.',
        false =>
          'Tidak ada tagihan. Unit dikembalikan ke pelanggan, dan notanya '
              'tercatat sudah diambil.',
      },
      child: Wrap(
        spacing: AppSpacing.xs,
        children: [
          ChoiceChip(
            label: const Text('TANPA BIAYA'),
            selected: _biayaBatal == false,
            onSelected: (_) => _pilihBiayaBatal(false),
            selectedColor: w.aksen.withValues(alpha: 0.15),
          ),
          ChoiceChip(
            label: const Text('ADA BIAYA'),
            selected: _biayaBatal == true,
            onSelected: (_) => _pilihBiayaBatal(true),
            selectedColor: w.aksen.withValues(alpha: 0.15),
          ),
        ],
      ),
    );
  }

  /// Keluhan garansi, pada nota garansi brand saja.
  ///
  /// Berdampingan dengan keluhan pelanggan, bukan menggantikannya: yang
  /// satu kata-kata pelanggan saat unit datang ("mati tiba-tiba"), yang
  /// satu hasil pengecekan teknisi ("NO POWER") -- dan yang kedua itulah
  /// yang dibaca brand di laporan garansi.
  Widget _kolomKeluhanGaransi() {
    final klaim = ref.watch(klaimBrandNotaProvider(widget.nota?.claimId));
    if (klaim == null) return const SizedBox.shrink();

    if (_keluhanGaransiDari != klaim.id) {
      _keluhanGaransiDari = klaim.id;
      _keluhanGaransi.text = klaim.keluhan ?? '';
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s),
      child: LabeledField(
        label: 'Keluhan Garansi',
        hint:
            'Hasil pengecekan teknisi — ini yang dipakai di laporan '
            'garansi.',
        child: TextFormField(
          controller: _keluhanGaransi,
          maxLines: 2,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: 'NO POWER'),
        ),
      ),
    );
  }

  /// Status nota biasa -- atau, pada nota garansi brand, status klaimnya.
  ///
  /// Klaimnya diikuti, bukan dibaca sekali saat formulir dibuka: daftar
  /// klaim bisa saja belum termuat saat itu, dan formulir yang terlanjur
  /// memilih daftar status nota biasa tidak akan pernah berpindah.
  Widget _kolomStatus() {
    final klaim = ref.watch(klaimBrandNotaProvider(widget.nota?.claimId));

    if (klaim == null) {
      // Nota yang akan menjadi garansi brand memakai status klaimnya, dan
      // klaim tidak mengenal pengiriman ke cabang: nota yang terlanjur
      // Dikirim ke Cabang akan ditarik kembali begitu status klaimnya
      // digerakkan.
      // Hanya bila klaim brand memang akan lahir dari simpanan ini --
      // pemilih jenis garansi hanya tampil dalam keadaan itu. Nota arsip
      // yang sudah bertanda garansi tanpa klaim tidak punya klaim yang
      // akan menurunkan statusnya, dan jenis garansi bawaannya ("brand")
      // tidak berarti apa-apa di sana.
      final garansiBrand =
          _garansi && _bolehUbahGaransi && _jenisGaransi == ClaimJenis.brand;
      return LabeledField(
        label: 'Status',
        child: DropdownButtonFormField<String>(
          initialValue: _status,
          isExpanded: true,
          items: [
            for (final s in ServiceStatus.all)
              if (!(garansiBrand &&
                  s == ServiceStatus.dikirimCabang &&
                  _status != s))
                DropdownMenuItem(value: s, child: Text(ServiceStatus.label(s))),
          ],
          onChanged: (v) => _gantiStatus(v!),
        ),
      );
    }

    final brand = ref.watch(namaBrandProvider)[klaim.brandId];
    return LabeledField(
      label: 'Status Garansi',
      hint:
          'Sama dengan status klaimnya — mengubahnya di sini ikut '
          'mengubah klaim.',
      child: DropdownButtonFormField<String>(
        key: ValueKey(klaim.id),
        initialValue: _statusKlaim ?? klaim.status,
        isExpanded: true,
        items: [
          for (final s in ClaimStatus.all)
            DropdownMenuItem(
              value: s,
              child: Text(ClaimStatus.label(s, brand: brand)),
            ),
        ],
        onChanged: (v) => setState(() => _statusKlaim = v),
      ),
    );
  }

  /// Jalan pintas ke tanya harga part.
  ///
  /// Dua bentuk, karena momennya dua. Saat nota baru dibuat, kebutuhannya
  /// sudah kelihatan di meja depan -- cukup satu centang, dan barisnya
  /// ikut lahir bersama notanya. Setelah nota tersimpan, kebutuhan itu
  /// biasanya baru ketahuan sesudah teknisi membuka unitnya, dan yang
  /// dibutuhkan adalah formulir tanya harga yang sudah terisi sendiri.
  ///
  /// Keduanya membawa data yang sama dan menghasilkan baris yang sama;
  /// yang berbeda hanya kapan admin sempat memikirkannya.
  Widget _tanyaHargaBagian(BuildContext context) {
    if (widget.isNew) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          CheckboxListTile(
            value: _tanyaHarga,
            onChanged: (v) => setState(() => _tanyaHarga = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text(
              'Perlu tanya harga part',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'Baris tanya harga dibuat otomatis dari data ini. Harga dan '
              'modalnya diisi belakangan di halaman Tanya Harga.',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          if (_tanyaHarga) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: LabeledField(
                    label: 'Part yang Dicari',
                    required: true,
                    child: TextFormField(
                      controller: _partReq,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        hintText: 'LCD 14 SLIM 30 PIN',
                      ),
                      // Hanya wajib selama centangnya menyala. Validator
                      // yang tetap galak setelah centangnya dilepas akan
                      // memblokir penyimpanan nota biasa.
                      validator: (v) => _tanyaHarga && (v ?? '').trim().isEmpty
                          ? 'Sebutkan part yang dicari'
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: LabeledField(
                    label: 'Keterangan',
                    child: DropdownButtonFormField<String>(
                      initialValue: _partKeterangan,
                      isExpanded: true,
                      hint: const Text('—'),
                      items: const [
                        DropdownMenuItem(value: 'oem', child: Text('OEM')),
                        DropdownMenuItem(value: 'ori', child: Text('ORI')),
                        DropdownMenuItem(value: 'copy', child: Text('Copy')),
                      ],
                      onChanged: (v) => setState(() => _partKeterangan = v),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      );
    }

    // Nota yang sudah tersimpan. Kalau tanya harganya sudah pernah dibuat,
    // yang ditawarkan membukanya -- bukan membuat yang kedua dengan isi
    // yang sama persis.
    final sudahAda = ref.watch(tanyaHargaNotaProvider(widget.nota!.id));

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s),
      decoration: BoxDecoration(
        color: context.warna.teredam,
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              sudahAda == null
                  ? 'Ternyata perlu ganti part? Datanya dibawa dari nota '
                        'ini — tinggal sebut partnya.'
                  : 'Sudah ada tanya harga untuk nota ini: '
                        '${sudahAda.partReq}.',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          const SizedBox(width: AppSpacing.s),
          OutlinedButton.icon(
            onPressed: () => showPartDialog(
              context,
              pesanan: sudahAda,
              awal: sudahAda != null ? null : _awalTanyaHarga(),
            ),
            icon: const Icon(Icons.request_quote_outlined, size: 17),
            label: Text(
              sudahAda == null ? 'TANYA HARGA PART' : 'LIHAT TANYA HARGA',
            ),
          ),
        ],
      ),
    );
  }

  /// Isian yang dibawa ke formulir tanya harga.
  ///
  /// Diambil dari kolom yang sedang tampil, bukan dari baris yang
  /// tersimpan: yang dilihat admin di layar itulah yang ia maksud, dan
  /// koreksi ketik yang belum sempat disimpan tetap ikut.
  AwalTanyaHarga _awalTanyaHarga() => AwalTanyaHarga(
    notaId: widget.nota!.id,
    customerNama: _nama.text.trim(),
    customerTelp: _kosongNull(_telp),
    customerId: _pelanggan?.id,
    // Merek dan tipe digabung: di tanya harga keduanya satu kolom, dan
    // yang berguna saat mencari part adalah sebutan lengkap unitnya.
    barangType: [
      _barang.text.trim(),
      _type.text.trim(),
    ].where((s) => s.isNotEmpty).join(' '),
    barangSn: _kosongNull(_sn),
    teknisiId: _teknisiId,
  );

  Widget _footer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.s,
        AppSpacing.sm,
        AppSpacing.s,
      ),
      decoration: BoxDecoration(
        color: context.warna.teredam,
        border: Border(top: BorderSide(color: context.warna.garisHalus)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _error != null
                ? Text(
                    _error!,
                    style: TextStyle(
                      color: context.warna.bahaya,
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
          // Cetak hanya untuk nota yang sudah tersimpan: sebelum itu
          // nomornya belum ada, dan nota tanpa nomor tidak ada gunanya.
          if (!widget.isNew && RawPrinter.didukung) ...[
            OutlinedButton(
              onPressed: _busy ? null : () => _cetak(JenisNota.masuk),
              child: const Text('CETAK MASUK'),
            ),
            const SizedBox(width: AppSpacing.xs),
            OutlinedButton(
              onPressed: _busy ? null : () => _cetak(JenisNota.keluar),
              child: const Text('CETAK KELUAR'),
            ),
            const SizedBox(width: AppSpacing.s),
          ],
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: const Text('BATAL'),
          ),
          const SizedBox(width: AppSpacing.xs),
          FilledButton(
            onPressed: _busy ? null : _simpan,
            child: _busy
                ? SizedBox(
                    height: 14,
                    width: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.warna.permukaan,
                    ),
                  )
                : Text(widget.isNew ? 'SIMPAN NOTA' : 'SIMPAN PERUBAHAN'),
          ),
        ],
      ),
    );
  }
}

/// Gaya tombol pemilih tanggal.
///
/// Berupa fungsi, bukan nilai tetap: bingkainya mengikuti tema yang
/// sedang berlaku, dan tema baru bisa dibaca setelah ada BuildContext.
ButtonStyle _tombolTanggal(BuildContext context) => OutlinedButton.styleFrom(
  alignment: Alignment.centerLeft,
  side: BorderSide(color: context.warna.garisIsian, width: 1),
  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s, vertical: 13),
);
