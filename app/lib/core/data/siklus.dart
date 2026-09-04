/// Apakah aplikasi sedang dilihat orang.
///
/// Dipakai penarikan berkala di [Db] untuk berhenti saat aplikasinya
/// ditidurkan. Tanpa ini, HP yang tergeletak di saku tetap menarik seluruh
/// isi tabel tiap menit sepanjang hari -- kuota yang habis tanpa satu pun
/// mata yang membacanya.
///
/// Sengaja sesederhana ini, bukan lewat provider: yang membacanya adalah
/// lapisan data yang tidak boleh tahu apa-apa tentang Riverpod maupun
/// widget.
class Siklus {
  const Siklus._();

  /// Dianggap aktif sampai ada yang bilang sebaliknya -- di Windows tidak
  /// ada yang pernah mengubahnya, dan di sana aplikasinya memang selalu
  /// terlihat selama jendelanya terbuka.
  static bool aktif = true;
}
