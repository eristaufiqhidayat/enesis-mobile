import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../data/session.dart';
import '../theme.dart';
import '../widgets/umum.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _lihat = false;
  bool _proses = false;
  String? _galat;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _masuk() async {
    if (_username.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _galat = 'Isi username dan password.');
      return;
    }

    setState(() {
      _proses = true;
      _galat = null;
    });

    try {
      await context.read<Session>().login(_username.text, _password.text);
    } on ApiException catch (e) {
      setState(() => _galat = e.pesanField('username') ?? e.message);
    } finally {
      if (mounted) setState(() => _proses = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pesanKeluar = context.watch<Session>().pesanKeluar;

    return Scaffold(
      backgroundColor: Warna.biruTua,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.local_shipping_outlined, size: 56, color: Colors.white),
                const SizedBox(height: 12),
                const Text('Enesis Motoris',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
                const Text('Masuk dengan akun Enesis Anda',
                    textAlign: TextAlign.center, style: TextStyle(color: Warna.biruHeaderTeks, fontSize: 14)),
                const SizedBox(height: 24),
                Kartu(
                  padding: const EdgeInsets.all(20),
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (pesanKeluar != null && _galat == null) ...[
                          Catatan(pesanKeluar, jenis: JenisCatatan.peringatan),
                          const SizedBox(height: 12),
                        ],
                        if (_galat != null) ...[
                          Catatan(_galat!, jenis: JenisCatatan.bahaya),
                          const SizedBox(height: 12),
                        ],
                        TextField(
                          controller: _username,
                          autofillHints: const [AutofillHints.username],
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.person_outline)),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _password,
                          obscureText: !_lihat,
                          autofillHints: const [AutofillHints.password],
                          onSubmitted: (_) => _masuk(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              tooltip: _lihat ? 'Sembunyikan password' : 'Tampilkan password',
                              icon: Icon(_lihat ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                              onPressed: () => setState(() => _lihat = !_lihat),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TombolUtama('Masuk', ikon: Icons.login, proses: _proses, onPressed: _masuk),
                        const SizedBox(height: 12),
                        const Text('Lupa password? Hubungi admin.', textAlign: TextAlign.center, style: TextStyle(color: Warna.redup)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Satu akun hanya aktif di satu HP. Login di HP ini akan mengeluarkan akun Anda dari HP lain.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Warna.biruHeaderTeks, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
