// Dua tema, satu arti.
//
// Yang diperiksa di sini bukan selera melainkan hal-hal yang bisa salah
// diam-diam: warna yang tidak terbaca di atas latarnya, arti yang tertukar
// antara terang dan gelap, dan pilihan yang tidak tersimpan.
//
// Kontrasnya dihitung, bukan dikira-kira. Palet gelap dipilih dari contoh
// yang dikirim lewat gambar, dan gambar selalu tampak lebih terbaca di
// layar besar yang terang daripada di HP teknisi di ruang belakang.

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sc_management/core/providers.dart';
import 'package:sc_management/core/theme.dart';
import 'package:sc_management/features/auth/login_page.dart';

/// Luminansi relatif menurut WCAG.
double _luminansi(Color c) {
  double kanal(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * kanal(c.r) + 0.7152 * kanal(c.g) + 0.0722 * kanal(c.b);
}

/// Rasio kontras WCAG antara dua warna. 1 berarti sama persis, 21 adalah
/// hitam murni di atas putih murni.
double kontras(Color a, Color b) {
  final la = _luminansi(a);
  final lb = _luminansi(b);
  final terang = math.max(la, lb);
  final gelap = math.min(la, lb);
  return (terang + 0.05) / (gelap + 0.05);
}

void main() {
  group('Kontras palet', () {
    test('teks utama terbaca jelas di kedua tema', () {
      // 7:1 adalah ambang AAA untuk teks biasa. Ini teks yang dibaca
      // sepanjang hari; tidak ada alasan berhenti di ambang minimum.
      expect(
        kontras(WarnaApp.terang.teks, WarnaApp.terang.latar),
        greaterThan(7),
      );
      expect(
        kontras(WarnaApp.gelap.teks, WarnaApp.gelap.latar),
        greaterThan(7),
      );
    });

    test('warna bermakna menonjol dari latarnya di mode gelap', () {
      // 3:1 adalah ambang WCAG untuk teks besar dan untuk elemen bukan
      // teks seperti bingkai penanda. Semua warna di bawah ini dipakai
      // untuk keduanya.
      final w = WarnaApp.gelap;
      for (final (nama, warna) in [
        ('aksen', w.aksen),
        ('bahaya', w.bahaya),
        ('garansi', w.garansi),
        ('teksLembut', w.teksLembut),
      ]) {
        expect(
          kontras(warna, w.latar),
          greaterThan(3),
          reason: '$nama tenggelam di latar gelap',
        );
      }
    });

    test('teks di atas aksen terbaca, bukan oranye di atas oranye', () {
      for (final w in [WarnaApp.terang, WarnaApp.gelap]) {
        expect(kontras(w.diAksen, w.aksen), greaterThan(3));
      }
    });

    test('kartu terpisah dari latar halaman di mode gelap', () {
      // Di mode terang keduanya sengaja sama putih, dan yang memisahkan
      // kartu adalah garis rambutnya. Di mode gelap kartunya sedikit
      // terangkat, jadi keduanya tidak boleh identik.
      expect(WarnaApp.gelap.permukaan, isNot(WarnaApp.gelap.latar));
      expect(
        kontras(WarnaApp.gelap.garisHalus, WarnaApp.gelap.permukaan),
        greaterThan(1.1),
        reason: 'bingkai kartu tidak terlihat sama sekali',
      );
    });

    test('teks lembut di mode terang memang di bawah ambang', () {
      // Bukan kelalaian, melainkan keadaan yang sudah berjalan: abu ini
      // dipakai sejak awal untuk kaption dan judul kolom, dan mengubahnya
      // berarti mengubah tampilan siang hari -- yang justru diminta untuk
      // tidak diubah.
      //
      // Ditulis sebagai test supaya angkanya tercatat dan tidak diam-diam
      // memburuk. Kalau suatu saat mode terang boleh disentuh, inilah yang
      // pertama diperbaiki.
      final r = kontras(WarnaApp.terang.teksLembut, WarnaApp.terang.latar);
      expect(r, lessThan(3), reason: 'sudah membaik -- perbarui test ini');
      expect(r, greaterThan(2), reason: 'jangan sampai lebih pudar lagi');
    });
  });

  group('Arti warna tidak tertukar antar tema', () {
    test('garansi hijau, bahaya merah, di kedua tema', () {
      for (final w in [WarnaApp.terang, WarnaApp.gelap]) {
        // Hijau: komponen hijaunya harus menang telak.
        expect(w.garansi.g, greaterThan(w.garansi.r));
        expect(w.garansi.g, greaterThan(w.garansi.b));
        // Merah: komponen merahnya harus menang telak.
        expect(w.bahaya.r, greaterThan(w.bahaya.g));
        expect(w.bahaya.r, greaterThan(w.bahaya.b));
      }
    });

    test('bahaya dan garansi jauh ronanya, bukan sekadar beda terang', () {
      // Yang membedakan keduanya harus rona, bukan terang. Rasio kontras
      // tidak bisa menjawab ini: merah #D82C2C dan hijau #1B8A4B hanya
      // berselisih 1,11 karena terangnya memang hampir sama, padahal
      // keduanya jelas berbeda bagi mata.
      //
      // Sisi lain dari angka itu: dua warna yang sama terangnya menjadi
      // abu yang sama persis di foto hitam putih. Di aplikasi ini warna
      // tidak pernah jadi satu-satunya penanda -- di sebelahnya selalu ada
      // tulisan GARANSI atau PIUTANG -- jadi yang dijaga di sini cukup
      // ronanya.
      for (final w in [WarnaApp.terang, WarnaApp.gelap]) {
        final merah = HSLColor.fromColor(w.bahaya).hue;
        final hijau = HSLColor.fromColor(w.garansi).hue;
        final selisih = (merah - hijau).abs();
        expect(
          math.min(selisih, 360 - selisih),
          greaterThan(60),
          reason: 'merah dan hijau terlalu berdekatan ronanya',
        );
      }
    });
  });

  group('Tema yang dibangun', () {
    test('keduanya membawa paletnya sendiri', () {
      expect(AppTheme.terang().extension<WarnaApp>(), WarnaApp.terang);
      expect(AppTheme.gelap().extension<WarnaApp>(), WarnaApp.gelap);
    });

    test('kecerahannya ikut, supaya widget bawaan Material tahu diri', () {
      // Beberapa widget Material memilih warnanya sendiri dari brightness,
      // bukan dari skema. Kalau ini salah, penanda kursor dan latar menu
      // muncul terang di tengah layar gelap.
      expect(AppTheme.terang().colorScheme.brightness, Brightness.light);
      expect(AppTheme.gelap().colorScheme.brightness, Brightness.dark);
    });

    test('latar halaman ikut palet, bukan putih bawaan Material', () {
      expect(AppTheme.gelap().scaffoldBackgroundColor, WarnaApp.gelap.latar);
    });
  });

  group('Layar sungguhan di mode gelap', () {
    // Warna mentah yang dulu ditulis langsung di kode halaman. Semuanya
    // sudah diganti, dan test ini yang menjaga supaya tidak ada yang
    // menyelinap masuk lagi: satu Color(0xFFFFFFFF) yang lolos akan
    // menyala putih di tengah layar biru tua, dan tidak ada satu pun galat
    // yang muncul karenanya.
    const warnaTerlarang = {
      'putih kertas': Color(0xFFFFFFFF),
      'garis rambut terang': Color(0xFFE4E7E7),
      'bingkai isian terang': Color(0xFFCFD5D4),
      'abu Swiss': Color(0xFFA9B2B1),
      'latar teredam terang': Color(0xFFF2F2F2),
    };

    testWidgets('tidak ada warna mode terang yang menyelinap', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.gelap(),
            home: const LoginPage(),
          ),
        ),
      );
      await tester.pump();

      final ditemukan = <String>{};
      for (final el in find.byType(DecoratedBox).evaluate()) {
        final d = (el.widget as DecoratedBox).decoration;
        if (d is! BoxDecoration) continue;
        for (final e in warnaTerlarang.entries) {
          if (d.color == e.value) ditemukan.add(e.key);
          if (d.border?.top.color == e.value) ditemukan.add('${e.key} (garis)');
        }
      }
      for (final el in find.byType(Text).evaluate()) {
        final c = (el.widget as Text).style?.color;
        for (final e in warnaTerlarang.entries) {
          if (c == e.value) ditemukan.add('${e.key} (teks)');
        }
      }

      expect(ditemukan, isEmpty, reason: 'warna mode terang di layar gelap');
    });

    testWidgets('latarnya benar-benar gelap', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.gelap(),
            home: const LoginPage(),
          ),
        ),
      );
      await tester.pump();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      final latar =
          scaffold.backgroundColor ?? AppTheme.gelap().scaffoldBackgroundColor;
      expect(_luminansi(latar), lessThan(0.1));
    });
  });

  group('Tidak ada warna mentah di luar palet', () {
    // Pemeriksaan di atas hanya menyentuh satu layar. Yang ini membaca
    // seluruh kode: satu warna yang ditulis langsung di halaman mana pun
    // akan tetap sama rupanya di kedua tema, dan itu tidak menimbulkan
    // galat apa pun -- hanya kotak putih menyala di layar biru tua yang
    // baru ketahuan saat seseorang membukanya malam hari.
    //
    // Yang tersisa hanya lapisan hitam tembus pandang: bayangan dan tirai
    // di belakang dialog. Keduanya memang hitam di kedua tema, karena
    // tugasnya meredupkan yang ada di bawahnya, bukan mewarnai.
    const dibolehkan = {
      '0x14000000', // bayangan kartu
      '0x1F000000', // bayangan kartu yang sedang diseret
      '0x26000000', // tirai di belakang dialog, mode kaca
      '0x33000000', // tirai di belakang dialog
      '0x80000000', // tirai bawaan showGeneralDialog
    };

    test('warna hanya lahir di warna.dart', () {
      final pelanggar = <String>[];
      final pola = RegExp(r'Color\((0x[0-9A-Fa-f]{8})\)');

      for (final f in Directory('lib').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        if (f.path.endsWith('warna.dart')) continue;
        // Palet mode kaca: warna dasar latar, isi bidang, dan bola cahaya
        // di belakangnya. Sama seperti warna.dart, di sinilah warna lahir.
        if (f.path.endsWith('gaya_kaca.dart')) continue;

        final isi = f.readAsStringSync();
        for (final m in pola.allMatches(isi)) {
          final kode = m.group(1)!.toUpperCase().replaceFirst('0X', '0x');
          if (dibolehkan.contains(kode)) continue;
          pelanggar.add('${f.path}: Color($kode)');
        }
      }

      expect(pelanggar, isEmpty, reason: pelanggar.join('\n'));
    });
  });

  group('Pilihan mode tersimpan', () {
    test('bolak-balik lewat teks yang disimpan', () {
      for (final m in ThemeMode.values) {
        expect(bacaModeTema(tulisModeTema(m)), m);
      }
    });

    test('bawaannya ikut sistem, termasuk saat nilainya tidak dikenal', () {
      // Perangkat yang belum pernah memilih, dan perangkat yang berkasnya
      // rusak atau berisi nilai dari versi lain, sama-sama harus jatuh ke
      // setelan sistemnya -- bukan dipaksa terang.
      expect(bacaModeTema(null), ThemeMode.system);
      expect(bacaModeTema(''), ThemeMode.system);
      expect(bacaModeTema('entah'), ThemeMode.system);
    });
  });
}
