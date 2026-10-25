import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/koordinator.dart';
import '../../../data/lokasi.dart';
import '../akun_screen.dart';
import 'beranda_koordinator_screen.dart';
import 'riwayat_join_visit_screen.dart';
import 'tim_screen.dart';

/// Kerangka setelah login untuk koordinator: Beranda · Tim · Join Visit · Akun.
class ShellKoordinator extends StatefulWidget {
  const ShellKoordinator({super.key});

  @override
  State<ShellKoordinator> createState() => _ShellKoordinatorState();
}

class _ShellKoordinatorState extends State<ShellKoordinator> with WidgetsBindingObserver {
  int _tab = 0;
  late final Koordinator _koor;
  late final Pelacak _pelacak;

  @override
  void initState() {
    super.initState();
    _koor = context.read<Koordinator>();
    _pelacak = context.read<Pelacak>();
    WidgetsBinding.instance.addObserver(this);
    _koor.addListener(_aturPelacak);
    _koor.muat();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _koor.removeListener(_aturPelacak);
    _pelacak.berhenti();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _koor.segarkan();
  }

  /// GPS dicatat sejak absen masuk sampai absen pulang (tampil di web Tracking Koordinator).
  void _aturPelacak() {
    final kerja = _koor.sudahAbsen && !_koor.sudahPulang;
    if (kerja && !_pelacak.aktif) {
      _pelacak.mulai(intervalDetik: (_koor.config['gps_interval_s'] as num?)?.toInt() ?? 180);
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
          BerandaKoordinatorScreen(bukaTim: () => bukaTab(1), bukaRiwayat: () => bukaTab(2)),
          const TimScreen(),
          const RiwayatJoinVisitScreen(),
          const AkunScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: bukaTab,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Beranda'),
          NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Tim'),
          NavigationDestination(icon: Icon(Icons.handshake_outlined), selectedIcon: Icon(Icons.handshake), label: 'Join Visit'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Akun'),
        ],
      ),
    );
  }
}
