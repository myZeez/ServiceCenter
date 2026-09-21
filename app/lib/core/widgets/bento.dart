import 'package:flutter/material.dart';

import '../theme.dart';

/// Kotak bento: satu unit isi dengan garis 1px dan judul kecil di atasnya.
///
/// Sengaja tanpa bayangan. Yang memisahkan satu kotak dari kotak lain
/// adalah garis dan ruang kosong, bukan kedalaman palsu.
class BentoCard extends StatelessWidget {
  const BentoCard({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.padding = const EdgeInsets.all(AppSpacing.sm),
    this.accent,
  });

  final Widget child;
  final String? title;
  final Widget? trailing;
  final EdgeInsets padding;

  /// Garis tebal di tepi atas. Dipakai hemat -- hanya untuk kotak yang
  /// memang perlu ditemukan lebih dulu dari yang lain.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.warna.permukaan,
        borderRadius: BorderRadius.circular(AppRadius.base),
        border: Border.all(color: context.warna.garisHalus),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (accent != null) Container(height: 3, color: accent),
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.s,
                AppSpacing.s,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title!.toUpperCase(),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
          Flexible(
            child: Padding(padding: padding, child: child),
          ),
        ],
      ),
    );
  }
}

/// Angka besar dengan label kecil. Bisa diklik untuk menyaring daftar --
/// jadi ringkasan dan kendali sekaligus, bukan hiasan yang berdiri sendiri.
class StatTile extends StatefulWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.accent,
    this.selected = false,
    this.onTap,
  });

  final String value;
  final String label;
  final Color? accent;
  final bool selected;
  final VoidCallback? onTap;

  @override
  State<StatTile> createState() => _StatTileState();
}

class _StatTileState extends State<StatTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent ?? context.warna.teks;
    final active = widget.selected;

    return MouseRegion(
      cursor: widget.onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s,
            AppSpacing.s,
            AppSpacing.s,
            AppSpacing.s,
          ),
          decoration: BoxDecoration(
            color: active ? accent : context.warna.permukaan,
            borderRadius: BorderRadius.circular(AppRadius.base),
            border: Border.all(
              color: active
                  ? accent
                  : (_hover ? accent : context.warna.garisHalus),
              width: active ? 1 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                  height: 1,
                  color: active ? context.warna.kertas : context.warna.teks,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.9,
                  color: active ? context.warna.kertas : context.warna.teksLembut,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kepala halaman: judul besar, keterangan singkat, tindakan di kanan.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: TextStyle(fontSize: 13, color: context.warna.teksLembut),
                ),
              ],
            ],
          ),
        ),
        ...actions,
      ],
    );
  }
}

/// Baris data ringkas di dalam kotak bento: label kiri, angka kanan, dengan
/// batang proporsi tipis di bawahnya.
class BentoBarRow extends StatelessWidget {
  const BentoBarRow({
    super.key,
    required this.label,
    required this.value,
    required this.fraction,
    this.color,
  });

  final String label;
  final String value;
  final double fraction;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          // Batang setipis ini cukup untuk membandingkan besaran tanpa
          // berubah menjadi grafik yang menuntut perhatian sendiri.
          Stack(
            children: [
              Container(height: 3, color: context.warna.teredam),
              FractionallySizedBox(
                widthFactor: fraction.clamp(0.0, 1.0),
                child: Container(height: 3, color: color ?? context.warna.teks),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
