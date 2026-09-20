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
    return Container(
      height: 36,
      // Lebar tetap, bukan sekadar batas bawah. Di kepala halaman kotak ini
      // berdiri tanpa lebar dari induknya, dan DropdownButton yang memuai
      // di ruang tak terbatas melempar galat tata letak.
      width: 168,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      decoration: BoxDecoration(
        border: Border.all(
          color: value == null ? context.warna.garisIsian : context.warna.teks,
        ),
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
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
    );
  }
}
