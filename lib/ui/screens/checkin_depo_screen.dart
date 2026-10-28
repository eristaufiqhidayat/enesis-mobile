import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../data/hari.dart';
import '../../data/lokasi.dart';
import '../theme.dart';
import '../widgets/umum.dart';

/// 02b Checkin depo: lokasi di dalam radius depo (tidak berubah). Terpisah dari
/// absen masuk ([AbsenScreen]) karena absen sekarang diperiksa terhadap area
/// kerja, bukan depo — sales bisa sudah absen tapi belum sampai di gudang.
class CheckinDepoScreen extends StatefulWidget {
  const CheckinDepoScreen({super.key});

  @override
  State<CheckinDepoScreen> createState() => _CheckinDepoScreenState();
}

class _CheckinDepoScreenState extends State<CheckinDepoScreen> {
  Titik? _titik;
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

  double? _jarak(Hari hari, Titik t) {
    final lat = hari.depo['lat'] as num?;
    final lng = hari.depo['lng'] as num?;
    return lat == null || lng == null ? null : t.jarakKe(lat.toDouble(), lng.toDouble());
  }

  Future<void> _simpan(Hari hari) async {
    final t = _titik;
    if (t == null) return tampilkanGalat(context, _galatLokasi ?? 'Lokasi belum didapat.');
    if (t.palsu) return tampilkanGalat(context, 'Lokasi palsu (mock location) terdeteksi. Matikan aplikasi pengubah lokasi.');

    final jarak = _jarak(hari, t);
    final radius = (hari.depo['radius_m'] as num?) ?? 100;
    if (jarak != null && jarak > radius) {
      return tampilkanGalat(context, 'Anda ${jarak.round()} m dari depo, batas ${radius.round()} m.');
    }

    setState(() => _proses = true);
    try {
      final antri = await hari.checkinDepo(t);
      if (!mounted) return;
      Navigator.of(context).pop();
      tampilkanHasil(context, antri, 'Checkin depo tercatat.');
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
    final jarak = t == null ? null : _jarak(hari, t);
    final radius = (hari.depo['radius_m'] as num?) ?? 100;
    final dalam = jarak == null || jarak <= radius;

    return Scaffold(
      body: Column(
        children: [
          const HeaderBiru(judul: 'Checkin depo'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Catatan('Absen masuk sudah tercatat. Datangi depo untuk ambil barang canvassing lalu checkin di sini.', jenis: JenisCatatan.sukses),
                const SizedBox(height: 12),
                Kartu(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: dalam ? Warna.suksesMuda : Warna.bahayaMuda,
                        child: Icon(Icons.warehouse_outlined, color: dalam ? Warna.sukses : Warna.bahaya),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Radius depo ${radius.round()} m', style: const TextStyle(fontSize: 12, color: Warna.redup)),
                            Text(
                              _cari
                                  ? 'Mencari lokasi…'
                                  : t == null
                                      ? (_galatLokasi ?? 'Lokasi belum didapat')
                                      : jarak == null
                                          ? 'Koordinat depo belum diatur'
                                          : 'Anda berada ${Fmt.jarak(jarak)} dari',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                            Text('Depo ${hari.depo['name'] ?? '-'}', style: const TextStyle(fontSize: 13, color: Warna.redup)),
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
                    children: [
                      BarisInfo('Jam HP', '${Fmt.jam(DateTime.now())} WIB', tebal: true),
                      BarisInfo('Koordinat', t == null ? '-' : '${t.lat.toStringAsFixed(4)}, ${t.lng.toStringAsFixed(4)}'),
                      BarisInfo('Akurasi GPS', t == null ? '-' : '± ${t.akurasi.round()} m'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Catatan('Tanpa sinyal? Checkin tetap tersimpan di HP dan dikirim otomatis ke Enesis saat online.'),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: TombolUtama(
                'Checkin depo',
                ikon: Icons.warehouse_outlined,
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
