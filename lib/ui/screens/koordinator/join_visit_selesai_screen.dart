import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/format.dart';
import '../../../data/koordinator.dart';
import '../../../data/lokasi.dart';
import '../../theme.dart';
import '../../widgets/umum.dart';

/// Selesaikan join visit: catatan hasil pendampingan dan foto bukti di outlet (keduanya wajib).
class JoinVisitSelesaiScreen extends StatefulWidget {
  const JoinVisitSelesaiScreen({super.key, required this.jv});

  final Map<String, dynamic> jv;

  @override
  State<JoinVisitSelesaiScreen> createState() => _JoinVisitSelesaiScreenState();
}

class _JoinVisitSelesaiScreenState extends State<JoinVisitSelesaiScreen> {
  final _catatan = TextEditingController();
  String? _foto;
  bool _proses = false;

  @override
  void dispose() {
    _catatan.dispose();
    super.dispose();
  }

  Future<void> _selesai(Koordinator koor) async {
    if (_catatan.text.trim().isEmpty) return tampilkanGalat(context, 'Tulis catatan hasil join visit.');
    if (_foto == null) return tampilkanGalat(context, 'Ambil foto di outlet dulu.');

    setState(() => _proses = true);
    try {
      Titik? t;
      try {
        t = await Lokasi.sekarang();
      } on LokasiException {
        // Lokasi selesai tidak wajib.
      }
      final antri = await koor.selesaiJoinVisit(widget.jv, _catatan.text, _foto!, t);
      if (!mounted) return;
      Navigator.of(context).pop();
      tampilkanHasil(context, antri, 'Join visit selesai.');
    } catch (e) {
      if (mounted) tampilkanGalat(context, e);
    } finally {
      if (mounted) setState(() => _proses = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final koor = context.read<Koordinator>();
    final jv = widget.jv;
    final mulai = Fmt.parse(jv['started_at']);

    return Scaffold(
      body: Column(
        children: [
          HeaderBiru(judul: 'Selesaikan join visit', subjudul: '${jv['outlet']?['name'] ?? '-'}'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Kartu(
                  child: Column(
                    children: [
                      BarisInfo('Sales', '${jv['sales']?['name'] ?? '-'}', tebal: true),
                      BarisInfo('Outlet', '${jv['outlet']?['code'] ?? ''} ${jv['outlet']?['name'] ?? ''}'.trim()),
                      BarisInfo('Mulai', '${Fmt.jam(mulai)} WIB'),
                      if (mulai != null) BarisInfo('Lama', '${DateTime.now().difference(mulai).inMinutes} menit'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Kartu(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Catatan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      const Text('Temuan dan arahan untuk sales: cara melayani toko, stok, display, kendala.',
                          style: TextStyle(fontSize: 13, color: Warna.redup)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _catatan,
                        maxLines: 5,
                        maxLength: 2000,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(hintText: 'Tulis catatan…'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Kartu(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Foto di outlet', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      FotoKotak(label: 'Ambil foto', path: _foto, tinggi: 180, onFoto: (p) => setState(() => _foto = p)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Catatan('Tanpa sinyal? Join visit tetap tersimpan di HP dan dikirim otomatis saat online.'),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: TombolUtama('Selesai', ikon: Icons.check, proses: _proses, onPressed: () => _selesai(koor)),
            ),
          ),
        ],
      ),
    );
  }
}
