import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../data/hari.dart';
import '../../data/lokasi.dart';
import '../theme.dart';
import '../widgets/umum.dart';

/// 02a Absen masuk: selfie + lokasi di dalam area kerja aktif sales (Master
/// Area), bukan radius depo. Checkin depo (radius depo) ada di layar terpisah,
/// [CheckinDepoScreen], karena area kerja sales bisa jauh dari gudang.
class AbsenScreen extends StatefulWidget {
  const AbsenScreen({super.key});

  @override
  State<AbsenScreen> createState() => _AbsenScreenState();
}

class _AbsenScreenState extends State<AbsenScreen> {
  Titik? _titik;
  String? _foto;
  String? _galatLokasi;
  bool _cari = false;
  bool _proses = false;

  @override
  void initState() {
    super.initState();
    _ambilLokasi();
  }

  Future<void> _ambilLokasi() async {
    setState(() {
      _cari = true;
      _galatLokasi = null;
    });
    try {
      final t = await Lokasi.sekarang();
      if (mounted) setState(() => _titik = t);
    } on LokasiException catch (e) {
      if (mounted) setState(() => _galatLokasi = e.message);
    } finally {
      if (mounted) setState(() => _cari = false);
    }
  }

  Future<void> _simpan(Hari hari) async {
    if (_foto == null) return tampilkanGalat(context, 'Ambil foto selfie dulu.');
    final t = _titik;
    if (t == null) return tampilkanGalat(context, _galatLokasi ?? 'Lokasi belum didapat.');
    if (t.palsu) return tampilkanGalat(context, 'Lokasi palsu (mock location) terdeteksi. Matikan aplikasi pengubah lokasi.');

    if (hari.areaKerja.isEmpty) {
      return tampilkanGalat(context, 'Anda belum punya area kerja aktif. Hubungi admin/koordinator.');
    }
    if (!hari.dalamAreaKerja(t)) {
      return tampilkanGalat(context, 'Anda di luar area kerja. Pindah ke salah satu area aktif Anda lalu coba lagi.');
    }

    setState(() => _proses = true);
    try {
      final antri = await hari.absenMasuk(_foto!, t);
      if (!mounted) return;
      Navigator.of(context).pop();
      tampilkanHasil(context, antri, 'Absen masuk tercatat.');
    } catch (e) {
      if (mounted) tampilkanGalat(context, e);
    } finally {
      if (mounted) setState(() => _proses = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hari = context.watch<Hari>();
    final t = _titik;
    final areas = hari.areaKerja;
    final dalam = t == null ? null : hari.dalamAreaKerja(t);
    final today = hari.config['today'] as Map? ?? {};

    return Scaffold(
      body: Column(
        children: [
          const HeaderBiru(judul: 'Absen masuk'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Kartu(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: dalam == true
                            ? Warna.suksesMuda
                            : dalam == false
                                ? Warna.bahayaMuda
                                : Warna.biruMuda,
                        child: Icon(
                          Icons.map_outlined,
                          color: dalam == true
                              ? Warna.sukses
                              : dalam == false
                                  ? Warna.bahaya
                                  : Warna.biruTua,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              areas.isEmpty ? 'Tidak ada area kerja aktif' : '${areas.length} area kerja aktif',
                              style: const TextStyle(fontSize: 12, color: Warna.redup),
                            ),
                            Text(
                              _cari
                                  ? 'Mencari lokasi…'
                                  : t == null
                                      ? (_galatLokasi ?? 'Lokasi belum didapat')
                                      : areas.isEmpty
                                          ? 'Belum punya area kerja'
                                          : dalam == true
                                              ? 'Anda di dalam area kerja'
                                              : 'Anda di luar area kerja',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      IconButton(onPressed: _cari ? null : _ambilLokasi, icon: const Icon(Icons.my_location), tooltip: 'Perbarui lokasi'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Kartu(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Foto selfie', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      const Text('Wajib untuk absen masuk. Pastikan wajah terlihat jelas.', style: TextStyle(fontSize: 13, color: Warna.redup)),
                      const SizedBox(height: 12),
                      FotoKotak(label: 'Ambil foto', path: _foto, depan: true, tinggi: 180, onFoto: (p) => setState(() => _foto = p)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Kartu(
                  child: Column(
                    children: [
                      BarisInfo('Jam HP', '${Fmt.jam(DateTime.now())} WIB', tebal: true),
                      BarisInfo('Batas masuk', '${today['check_in_deadline'] ?? '08:00'} WIB'),
                      BarisInfo('Koordinat', t == null ? '-' : '${t.lat.toStringAsFixed(4)}, ${t.lng.toStringAsFixed(4)}'),
                      BarisInfo('Akurasi GPS', t == null ? '-' : '± ${t.akurasi.round()} m'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (today['is_working_day'] == false)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Catatan('Hari ini ${today['holiday_name'] ?? 'bukan hari kerja'}. Absen akan ditolak server.', jenis: JenisCatatan.peringatan),
                  ),
                if (areas.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Catatan(
                      'Anda belum punya area kerja aktif di Master Area. Absen tidak bisa dilakukan sampai area diatur oleh admin/koordinator.',
                      jenis: JenisCatatan.peringatan,
                    ),
                  ),
                const Catatan('Tanpa sinyal? Absen tetap tersimpan di HP dan dikirim otomatis ke Enesis saat online.'),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: TombolUtama(
                'Absen masuk',
                ikon: Icons.how_to_reg,
                proses: _proses,
                onPressed: () => _simpan(hari),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
