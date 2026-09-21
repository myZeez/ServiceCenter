import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/kaca/panel_kaca.dart';
import '../../core/theme.dart';

/// Pemindaian hanya tersedia di perangkat berkamera yang didukung plugin.
/// Di Windows tombolnya tidak ditampilkan sama sekali -- lebih baik tidak
/// ada daripada ada tapi gagal saat ditekan.
bool get scanSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// Membuka pemindai dan mengembalikan isi barcode, atau null bila dibatalkan.
Future<String?> scanBarcode(BuildContext context, {String? title}) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => ScanPage(title: title ?? 'Pindai Serial Number'),
    ),
  );
}

class ScanPage extends StatefulWidget {
  const ScanPage({super.key, required this.title});

  final String title;

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  // Barcode SN pada unit umumnya Code 128 atau Code 39, tapi sebagian
  // vendor memakai QR atau Data Matrix. Format sengaja tidak dibatasi.
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;

    final value = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere(
          (v) => v != null && v.trim().isNotEmpty,
          orElse: () => null,
        );

    if (value == null) return;

    // Sekali kena, langsung tutup. Tanpa penjaga ini kamera bisa
    // mengirim beberapa hasil sebelum halaman sempat ditutup.
    _handled = true;
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(value.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.warna.teks,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _ScannerError(error: error),
          ),
          const _Viewfinder(),
          _TopBar(title: widget.title, controller: _controller),
          const _BottomHint(),
        ],
      ),
    );
  }
}

/// Bingkai bidik: empat siku merah, tanpa kotak penuh. Cukup untuk
/// mengarahkan mata tanpa menutupi gambar.
class _Viewfinder extends StatelessWidget {
  const _Viewfinder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 280,
        height: 170,
        child: Stack(
          children: [
            for (final a in [
              Alignment.topLeft,
              Alignment.topRight,
              Alignment.bottomLeft,
              Alignment.bottomRight,
            ])
              Align(
                alignment: a,
                child: _Corner(alignment: a),
              ),
          ],
        ),
      ),
    );
  }
}

class _Corner extends StatelessWidget {
  const _Corner({required this.alignment});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final side = BorderSide(color: context.warna.bahaya, width: 3);
    final top = alignment.y < 0;
    final left = alignment.x < 0;

    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        border: Border(
          top: top ? side : BorderSide.none,
          bottom: top ? BorderSide.none : side,
          left: left ? side : BorderSide.none,
          right: left ? BorderSide.none : side,
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.controller});

  final String title;
  final MobileScannerController controller;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s),
        // Kaca di atas gambar kamera: yang di belakang tombol jadi kabur,
        // jadi ikon putih tetap terbaca di atas apa pun yang sedang
        // disorot.
        child: PanelKaca(
          tingkat: TingkatKaca.sedang,
          radius: BorderRadius.circular(AppRadius.base * 2),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.close, color: context.warna.kertas),
                onPressed: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    color: context.warna.kertas,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
              ValueListenableBuilder<MobileScannerState>(
                valueListenable: controller,
                builder: (context, state, _) {
                  if (state.torchState == TorchState.unavailable) {
                    return const SizedBox.shrink();
                  }
                  final on = state.torchState == TorchState.on;
                  return IconButton(
                    tooltip: 'Senter',
                    icon: Icon(
                      on ? Icons.flashlight_on : Icons.flashlight_off,
                      color: on ? context.warna.bahaya : context.warna.kertas,
                    ),
                    onPressed: controller.toggleTorch,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomHint extends StatelessWidget {
  const _BottomHint();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: PanelKaca(
            tingkat: TingkatKaca.sedang,
            radius: BorderRadius.circular(AppRadius.base * 2),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: Text(
                'Arahkan ke barcode serial number',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.warna.kertas.withValues(alpha: 0.75),
                  fontSize: 12,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScannerError extends StatelessWidget {
  const _ScannerError({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;

    return ColoredBox(
      color: context.warna.teks,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.no_photography_outlined,
                color: context.warna.kertas,
                size: 32,
              ),
              const SizedBox(height: AppSpacing.s),
              Text(
                denied ? 'Izin kamera ditolak' : 'Kamera tidak bisa dibuka',
                style: TextStyle(
                  color: context.warna.kertas,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                denied
                    ? 'Aktifkan izin kamera untuk aplikasi ini lewat '
                          'Setelan, lalu buka pemindai lagi. SN tetap bisa '
                          'diketik manual.'
                    : error.errorDetails?.message ?? error.errorCode.name,
                style: TextStyle(
                  color: context.warna.kertas.withValues(alpha: 0.75),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.warna.kertas,
                  side: BorderSide(color: context.warna.kertas, width: 1.5),
                ),
                child: const Text('KETIK MANUAL'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tombol pindai untuk ditempel sebagai suffix pada kolom isian.
/// Otomatis tidak muncul di platform yang tidak mendukung kamera.
class ScanFieldButton extends StatelessWidget {
  const ScanFieldButton({super.key, required this.onScanned, this.title});

  final ValueChanged<String> onScanned;
  final String? title;

  @override
  Widget build(BuildContext context) {
    if (!scanSupported) return const SizedBox.shrink();

    return IconButton(
      tooltip: 'Pindai barcode',
      iconSize: 20,
      color: context.warna.teks,
      icon: const Icon(Icons.qr_code_scanner),
      onPressed: () async {
        final value = await scanBarcode(context, title: title);
        if (value != null) onScanned(value);
      },
    );
  }
}
