import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/hari.dart';
import '../../data/lokasi.dart';
import 'akun_screen.dart';
import 'beranda_screen.dart';
import 'kinerja_screen.dart';
import 'rute_screen.dart';

/// Kerangka setelah login: menu bawah Beranda · Rute · Kinerja · Akun (seperti mockup).
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  int _tab = 0;
  late final Hari _hari;
  late final Pelacak _pelacak;

  @override
  void initState() {
    super.initState();
    _hari = context.read<Hari>();
    _pelacak = context.read<Pelacak>();
    WidgetsBinding.instance.addObserver(this);
    _hari.addListener(_aturPelacak);
    _hari.muat();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hari.removeListener(_aturPelacak);
    _hari.aktif = false;
    _pelacak.berhenti();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Kembali ke aplikasi: kirim antrian dan perbarui data.
    if (state == AppLifecycleState.resumed) _hari.segarkan();
  }

  /// GPS dicatat sejak absen masuk sampai tutup hari.
  void _aturPelacak() {
    final kerja = _hari.sudahAbsen && !_hari.sudahTutup;
    if (kerja && !_pelacak.aktif) {
      _pelacak.mulai(intervalDetik: (_hari.config['gps_interval_s'] as num?)?.toInt() ?? 180);
    } else if (!kerja && _pelacak.aktif) {
      _pelacak.berhenti();
    }
  }

  void bukaTab(int i) => setState(() => _tab = i);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          BerandaScreen(bukaRute: () => bukaTab(1)),
          const RuteScreen(),
          const KinerjaScreen(),
          const AkunScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: bukaTab,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Beranda'),
          NavigationDestination(icon: Icon(Icons.route_outlined), selectedIcon: Icon(Icons.route), label: 'Rute'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Kinerja'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Akun'),
        ],
      ),
    );
  }
}
