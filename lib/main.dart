import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api_client.dart';
import 'core/local_db.dart';
import 'core/outbox.dart';
import 'data/hari.dart';
import 'data/koordinator.dart';
import 'data/lokasi.dart';
import 'data/session.dart';
import 'ui/screens/ganti_password_screen.dart';
import 'ui/screens/koordinator/shell_koordinator.dart';
import 'ui/screens/login_screen.dart';
import 'ui/screens/shell.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final local = await LocalDb.open();
  final api = ApiClient();
  final session = Session(api, local);
  final outbox = Outbox(SqfliteOutboxStore(local), api)..start();
  final hari = Hari(api, local, outbox);
  final koordinator = Koordinator(api, local, outbox);
  final pelacak = Pelacak(local, api);
  await session.init();

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: session),
      ChangeNotifierProvider.value(value: outbox),
      ChangeNotifierProvider.value(value: hari),
      ChangeNotifierProvider.value(value: koordinator),
      Provider.value(value: pelacak),
    ],
    child: const EnesisApp(),
  ));
}

class EnesisApp extends StatelessWidget {
  const EnesisApp({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();

    final Widget beranda;
    if (!session.siap) {
      beranda = const Scaffold(body: Center(child: CircularProgressIndicator()));
    } else if (!session.masuk) {
      beranda = const LoginScreen();
    } else if (session.wajibGantiPassword) {
      beranda = const GantiPasswordScreen(wajib: true);
    } else if (session.adalahKoordinator) {
      // Satu aplikasi: koordinator mendapat menu koordinator (Beranda · Tim · Join Visit · Akun).
      beranda = ShellKoordinator(key: ValueKey(session.profil?['id']));
    } else {
      beranda = Shell(key: ValueKey(session.profil?['id']));
    }

    return MaterialApp(
      title: 'Enesis Motoris',
      debugShowCheckedModeBanner: false,
      theme: temaEnesis(),
      home: beranda,
    );
  }
}
