import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/format.dart';
import '../../../data/koordinator.dart';
import '../../../data/lokasi.dart';
import '../../theme.dart';
import '../../widgets/umum.dart';

/// Absen koordinator: masuk (selfie + lokasi) atau pulang. Tampil di web menu Absensi Koordinator.
class AbsenKoordinatorScreen extends StatefulWidget {
  const AbsenKoordinatorScreen({super.key});

  @override
  State<AbsenKoordinatorScreen> createState() => _AbsenKoordinatorScreenState();
}

class _AbsenKoordinatorScreenState extends State<AbsenKoordinatorScreen> {
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

  Future<void> _simpan(Koordinator koor) async {
    final pulang = koor.sudahAbsen;
    final t = _titik;

    if (pulang && koor.joinVisitBerjalan != null) {
      return tampilkanGalat(context, 'Selesaikan join visit dulu sebelum absen pulang.');
    }
    if (!pulang && _foto == null) return tampilkanGalat(context, 'Ambil foto selfie dulu.');
    if (!pulang && t == null) return tampilkanGalat(context, _galatLokasi ?? 'Lokasi belum didapat.');
    if (t != null && t.palsu) return tampilkanGalat(context, 'Lokasi palsu (mock location) terdeteksi. Matikan aplikasi pengubah lokasi.');

    if (!pulang) {
      if (koor.areaKerja.isEmpty) {
        return tampilkanGalat(context, 'Tim Anda belum punya area kerja aktif. Hubungi admin.');
      }
      if (!koor.dalamAreaKerja(t!)) {
        return tampilkanGalat(context, 'Anda di luar area kerja tim. Pindah ke salah satu area aktif tim Anda lalu coba lagi.');
      }
    }

    setState(() => _proses = true);
    try {
      final antri = pulang ? await koor.absenPulang(t) : await koor.absenMasuk(_foto!, t!);
      if (!mounted) return;
      Navigator.of(context).pop();
      tampilkanHasil(context, antri, pulang ? 'Absen pulang tercatat.' : 'Absen masuk tercatat.');
    } catch (e) {
      if (mounted) tampilkanGalat(context, e);
    } finally {
      if (mounted) setState(() => _proses = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final koor = context.watch<Koordinator>();
    final pulang = koor.sudahAbsen;
    final t = _titik;
    final areas = koor.areaKerja;
    final dalam = t == null ? null : koor.dalamAreaKerja(t);
    final today = koor.config['today'] as Map? ?? {};

    return Scaffold(
      body: Column(
        children: [
          HeaderBiru(judul: pulang ? 'Absen pulang' : 'Absen masuk'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Kartu(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: pulang
                            ? Warna.biruMuda
                            : dalam == true
                                ? Warna.suksesMuda
                                : dalam == false
                                    ? Warna.bahayaMuda
                                    : Warna.biruMuda,
                        child: Icon(
                          Icons.map_outlined,
                          color: pulang
                              ? Warna.biruTua
                              : dalam == true
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
                            if (!pulang)
                              Text(
                                areas.isEmpty ? 'Tidak ada area kerja tim' : '${areas.length} area kerja tim aktif',
                                style: const TextStyle(fontSize: 12, color: Warna.redup),
                              ),
                            Text(
                              _cari
                                  ? 'Mencari lokasi…'
                                  : t == null
                                      ? (_galatLokasi ?? 'Lokasi belum didapat')
                                      : pulang
                                          ? 'Lokasi didapat (± ${t.akurasi.round()} m)'
                                          : areas.isEmpty
                                              ? 'Tim belum punya area kerja'
                                              : dalam == true
                                                  ? 'Anda di dalam area kerja tim'
                                                  : 'Anda di luar area kerja tim',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      IconButton(onPressed: _cari ? null : _ambilLokasi, icon: const Icon(Icons.refresh), tooltip: 'Perbarui lokasi'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (!pulang) ...[
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
                ] else if (koor.joinVisitBerjalan != null) ...[
                  const Catatan('Masih ada join visit yang berjalan. Selesaikan dulu sebelum absen pulang.', jenis: JenisCatatan.peringatan),
                  const SizedBox(height: 12),
                ],
                Kartu(
                  child: Column(
                    children: [
                      BarisInfo('Jam HP', '${Fmt.jam(DateTime.now())} WIB', tebal: true),
                      if (!pulang) BarisInfo('Batas masuk', '${today['check_in_deadline'] ?? '08:00'} WIB'),
                      if (pulang) BarisInfo('Absen masuk', '${Fmt.jam(koor.jamMasuk)} WIB'),
                      BarisInfo('Koordinat', t == null ? '-' : '${t.lat.toStringAsFixed(4)}, ${t.lng.toStringAsFixed(4)}'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (today['is_working_day'] == false)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Catatan('Hari ini ${today['holiday_name'] ?? 'bukan hari kerja'}. Absen akan ditolak server.', jenis: JenisCatatan.peringatan),
                  ),
                if (!pulang && areas.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Catatan(
                      'Tim Anda belum punya area kerja aktif (gabungan area aktif sales di tim). Absen tidak bisa dilakukan sampai area diatur oleh admin.',
                      jenis: JenisCatatan.peringatan,
                    ),
                  ),
                const Catatan('Lokasi Anda dicatat berkala selama jam kerja dan tampil di web Tracking Koordinator.'),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: TombolUtama(
                pulang ? 'Absen pulang' : 'Absen masuk',
                ikon: pulang ? Icons.logout : Icons.how_to_reg,
                proses: _proses,
                onPressed: () => _simpan(koor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
