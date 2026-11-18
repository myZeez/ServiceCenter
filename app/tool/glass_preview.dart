// Pratinjau mandiri dock dan kepala Liquid Glass, tanpa login Supabase.
//
//   flutter run -d chrome  -t tool/glass_preview.dart
//   flutter run -d windows -t tool/glass_preview.dart
//
// Catatan: pembiasan premium (lensa bening, bevel) hanya muncul di Impeller
// -- Android atau iOS. Chrome dan Windows memakai shader `standard`.
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'package:sc_management/core/kaca/kepala_mengambang.dart';
import 'package:sc_management/core/kaca/kerangka_app.dart';
import 'package:sc_management/features/claims/dock_utama.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidGlassWidgets.initialize();
  runApp(
    LiquidGlassWidgets.wrap(
      brightnessResolver: Theme.maybeBrightnessOf,
      child: const KerangkaApp(kaca: true, home: _Halaman()),
    ),
  );
}

class _Halaman extends StatefulWidget {
  const _Halaman();

  @override
  State<_Halaman> createState() => _HalamanState();
}

class _HalamanState extends State<_Halaman> {
  TabUtama _tab = TabUtama.klaim;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Servisku')),
      body: Stack(
        children: [
          KepalaMengambang(
            kepala: const Padding(
              padding: EdgeInsets.all(12),
              child: TextField(
                decoration: InputDecoration(hintText: 'Cari no nota, nama'),
              ),
            ),
            isi: (context, atas) => ListView.builder(
              padding: EdgeInsets.fromLTRB(
                12,
                atas + 8,
                12,
                DockUtama.ruangBawah(context),
              ),
              itemCount: 30,
              itemBuilder: (_, i) => Card(
                color: Colors.primaries[i % Colors.primaries.length].shade300,
                child: ListTile(
                  title: Text('SVR-1511262916$i'),
                  subtitle: const Text('Laptop Asus Vivobook S14'),
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: DockUtama.jarak + MediaQuery.paddingOf(context).bottom,
            child: Align(
              alignment: Alignment.bottomCenter,
              heightFactor: 1,
              child: DockUtama(
                tab: _tab,
                jumlahServisku: 40,
                onTab: (t) => setState(() => _tab = t),
                onKlaimBaru: () {},
              ),
            ),
          ),
        ],
      ),
    );
  }
}
