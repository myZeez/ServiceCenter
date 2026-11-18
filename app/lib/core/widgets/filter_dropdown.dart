import 'package:flutter/material.dart';

import '../theme.dart';

/// Dropdown penyaring di kepala halaman: satu pilihan, dengan "semua"
/// sebagai [placeholder] yang bernilai null.
///
/// Dipakai Rekap dan Rekap Brand, supaya keduanya tampil dan bekerja sama.
class FilterDropdown<T> extends StatelessWidget {
  const FilterDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.placeholder,
  });

  final T value;
  final String? placeholder;
  final List<(T, String)> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final dipilih = value != null;
    return Container(
      width: 168,
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      decoration: BoxDecoration(
        color: context.warna.permukaan,
        borderRadius: BorderRadius.circular(AppRadius.small),
        border: Border.all(
          color: dipilih ? context.warna.teks : context.warna.garisIsian,
        ),
      ),
      child: Center(
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isDense: true,
            isExpanded: true,
            borderRadius: BorderRadius.circular(AppRadius.base),
            // Tanpa ini, Flutter melukis blok abu di belakang teks saat
            // dropdown mendapat fokus -- terlihat seperti kerusakan tampilan.
            focusColor: Colors.transparent,
            icon: const Icon(Icons.expand_more, size: 16),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: context.warna.teks,
            ),
            onChanged: onChanged,
            items: [
              if (placeholder != null)
                DropdownMenuItem<T>(value: null, child: Text(placeholder!)),
              for (final (v, label) in items)
                DropdownMenuItem<T>(value: v, child: Text(label)),
            ],
          ),
        ),
      ),
    );
  }
}
