import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../data/session.dart';
import '../widgets/umum.dart';

/// Ganti password. [wajib] = password awal dari admin: password lama tidak diminta.
class GantiPasswordScreen extends StatefulWidget {
  const GantiPasswordScreen({super.key, this.wajib = false});

  final bool wajib;

  @override
  State<GantiPasswordScreen> createState() => _GantiPasswordScreenState();
}

class _GantiPasswordScreenState extends State<GantiPasswordScreen> {
  final _lama = TextEditingController();
  final _baru = TextEditingController();
  final _ulang = TextEditingController();
  bool _proses = false;
  Map<String, String?> _galat = {};

  @override
  void dispose() {
    _lama.dispose();
    _baru.dispose();
    _ulang.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    final g = <String, String?>{};
    if (!widget.wajib && _lama.text.isEmpty) g['current_password'] = 'Password lama wajib diisi.';
    if (_baru.text.length < 8) g['password'] = 'Password baru minimal 8 karakter.';
    if (_baru.text != _ulang.text) g['ulang'] = 'Konfirmasi password tidak sama.';
    setState(() => _galat = g);
    if (g.isNotEmpty) return;

    setState(() => _proses = true);
    final session = context.read<Session>();
    try {
      await session.gantiPassword(passwordLama: widget.wajib ? null : _lama.text, passwordBaru: _baru.text);
      if (!mounted) return;
      if (!widget.wajib) {
        Navigator.of(context).pop();
        tampilkanInfo(context, 'Password sudah diganti.');
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _galat = {
            'current_password': e.pesanField('current_password'),
            'password': e.pesanField('password') ?? (e.fields.isEmpty ? e.message : null),
          });
    } finally {
      if (mounted) setState(() => _proses = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          HeaderBiru(
            judul: 'Ganti password',
            subjudul: widget.wajib ? 'Wajib sebelum memakai aplikasi' : null,
            aksi: widget.wajib
                ? TextButton(
                    onPressed: () => context.read<Session>().logout(),
                    child: const Text('Keluar', style: TextStyle(color: Colors.white)),
                  )
                : null,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (widget.wajib) ...[
                  const Catatan('Anda masih memakai password awal dari admin. Buat password baru (minimal 8 karakter, tidak sama dengan username).'),
                  const SizedBox(height: 12),
                ],
                Kartu(
                  child: Column(
                    children: [
                      if (!widget.wajib) ...[
                        TextField(
                          controller: _lama,
                          obscureText: true,
                          decoration: InputDecoration(labelText: 'Password lama', errorText: _galat['current_password']),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: _baru,
                        obscureText: true,
                        decoration: InputDecoration(labelText: 'Password baru', errorText: _galat['password']),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _ulang,
                        obscureText: true,
                        decoration: InputDecoration(labelText: 'Ulangi password baru', errorText: _galat['ulang']),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TombolUtama('Simpan password', proses: _proses, onPressed: _simpan),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
