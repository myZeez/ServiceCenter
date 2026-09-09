import 'package:flutter/material.dart';

import '../theme.dart';

/// Label di atas kolom isian, bukan label mengambang di dalamnya.
///
/// Gaya ini menaruh nama kolom sebagai penanda tetap: posisinya tidak
/// berubah saat kolom diisi, jadi mata tidak perlu mengejar teks yang
/// bergerak saat mengisi formulir panjang.
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.child,
    this.required = false,
    this.hint,
  });

  final String label;
  final Widget child;
  final bool required;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label.toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium,
            ),
            if (required)
              const Text(
                ' *',
                style: TextStyle(
                  color: context.warna.bahaya,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        child,
        if (hint != null) ...[
          const SizedBox(height: 4),
          Text(hint!, style: Theme.of(context).textTheme.labelSmall),
        ],
      ],
    );
  }
}

/// Penanda bagian. Huruf besar dengan tracking longgar, diikuti garis penuh --
/// pembagi horizontal adalah cara grid Swiss menyatakan pergantian bagian.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                text.toUpperCase(),
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(height: 1, color: context.warna.teks),
      ],
    );
  }
}

/// Sepasang label kecil di atas nilai. Dipakai di halaman detail.
class FieldValue extends StatelessWidget {
  const FieldValue(this.label, this.value, {super.key, this.emphasis = false});

  final String label;
  final String value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: emphasis
              ? Theme.of(context).textTheme.titleMedium
              : Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.3),
        ),
      ],
    );
  }
}

/// Keadaan kosong: ikon, keterangan, dan satu tindakan. Tanpa emoji.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                border: Border.all(color: context.warna.teks, width: 1.5),
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: Icon(icon, size: 22, color: context.warna.teks),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            if (description != null) ...[
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Text(
                  description!,
                  style: const TextStyle(color: context.warna.teksLembut, height: 1.5),
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.sm),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Masuk dengan pudar + geser 16px ke atas. Bertahap 80ms per item supaya
/// daftar terbaca sebagai urutan, bukan muncul serentak.
class EntryAnimation extends StatefulWidget {
  const EntryAnimation({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  @override
  State<EntryAnimation> createState() => _EntryAnimationState();
}

class _EntryAnimationState extends State<EntryAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void initState() {
    super.initState();
    // Item jauh di bawah layar tidak perlu ikut antre; batasi agar daftar
    // panjang tidak terasa lambat.
    final delay = (widget.index.clamp(0, 8)) * 80;
    Future<void>.delayed(Duration(milliseconds: delay), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return AnimatedBuilder(
      animation: curve,
      builder: (context, child) => Opacity(
        opacity: curve.value,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - curve.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// Tombol teks kecil dengan garis bawah, dipakai untuk aksi sekunder di
/// dalam kartu.
class InlineAction extends StatelessWidget {
  const InlineAction({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: context.warna.aksen,
            decoration: TextDecoration.underline,
            decorationColor: context.warna.aksen,
          ),
        ),
      ),
    );
  }
}

/// Judul kolom tabel: huruf besar kecil dengan tracking longgar.
///
/// Sengaja tidak membungkus ke baris kedua. Judul kolom yang tiba-tiba
/// setinggi dua baris menggeser seluruh kepala tabel dan membuat lebarnya
/// tampak berubah sendiri saat jendela diperkecil.
class TableHeader extends StatelessWidget {
  const TableHeader(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    overflow: TextOverflow.clip,
    softWrap: false,
    style: const TextStyle(
      fontSize: 9.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 1,
      color: context.warna.teks,
    ),
  );
}

/// Tombol ekspor yang menahan dirinya selama berkasnya disusun, lalu
/// menyebutkan di mana ia tersimpan.
///
/// Menyebut jalurnya penting: dialog simpan bawaan sistem sering
/// meninggalkan berkas di folder yang bukan pilihan siapa pun, dan
/// laporan yang tidak bisa ditemukan sama saja dengan tidak diekspor.
class TombolExport extends StatefulWidget {
  const TombolExport({
    super.key,
    required this.onExport,
    this.aktif = true,
    this.label = 'EXPORT EXCEL',
  });

  /// Mengembalikan jalur berkasnya, atau null bila pengguna membatalkan.
  final Future<String?> Function() onExport;

  final bool aktif;
  final String label;

  @override
  State<TombolExport> createState() => _TombolExportState();
}

class _TombolExportState extends State<TombolExport> {
  bool _sibuk = false;

  Future<void> _jalankan() async {
    setState(() => _sibuk = true);
    try {
      final jalur = await widget.onExport();
      if (!mounted || jalur == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tersimpan di $jalur'),
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal menyimpan berkas. $e')));
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: widget.aktif && !_sibuk ? _jalankan : null,
    icon: Icon(
      _sibuk ? Icons.hourglass_empty : Icons.file_download_outlined,
      size: 17,
    ),
    label: Text(widget.label),
  );
}
