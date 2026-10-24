import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../data/hari.dart';
import '../../data/lokasi.dart';
import '../theme.dart';
import '../widgets/umum.dart';
import 'kunjungan_screen.dart';

/// 07 Outlet baru (NOO): foto, data pemilik, tipe, lokasi GPS; lalu langsung checkin.
class OutletBaruScreen extends StatefulWidget {
  const OutletBaruScreen({super.key});

  @override
  State<OutletBaruScreen> createState() => _OutletBaruScreenState();
}

class _OutletBaruScreenState extends State<OutletBaruScreen> {
  final _nama = TextEditingController();
  final _pemilik = TextEditingController();
  final _hp = TextEditingController();
  final _alamat = TextEditingController();
  String? _fotoToko;
  String? _fotoRak;
  String? _tipe;
  Titik? _titik;
  String? _galatLokasi;
  bool _proses = false;

  // Hasil yang sudah tersimpan, dipakai ulang bila tombol ditekan lagi (duplikat / checkin gagal).
  final _refFoto = <String, String>{}; // path foto -> @ref
  String? _refOutlet;

  @override
  void initState() {
    super.initState();
    _lokasi();
  }

  @override
  void dispose() {
    for (final c in [_nama, _pemilik, _hp, _alamat]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _lokasi() async {
    setState(() => _galatLokasi = null);
    try {
      final t = await Lokasi.sekarang();
      if (mounted) setState(() => _titik = t);
    } on LokasiException catch (e) {
      if (mounted) setState(() => _galatLokasi = e.message);
    }
  }

  Future<void> _simpan(Hari hari, {bool bukanDuplikat = false}) async {
    if (_fotoToko == null) return tampilkanGalat(context, 'Foto depan toko wajib.');
    if (_nama.text.trim().isEmpty) return tampilkanGalat(context, 'Nama outlet wajib diisi.');
    final t = _titik;
    if (t == null) return tampilkanGalat(context, _galatLokasi ?? 'Lokasi belum didapat.');
    if (t.palsu) return tampilkanGalat(context, 'Lokasi palsu (mock location) terdeteksi.');

    setState(() => _proses = true);
    final nav = Navigator.of(context);
    try {
      Future<String> foto(String path, String jenis) async =>
          _refFoto[path] ??= await hari.unggahFoto(path, jenis, 'Foto $jenis ${_nama.text.trim()}');

      final ref = _refOutlet ??= await hari.daftarOutletBaru(
        nama: _nama.text.trim(),
        pemilik: _pemilik.text.trim(),
        hp: _hp.text.trim(),
        tipe: _tipe,
        alamat: _alamat.text.trim(),
        t: t,
        fotoToko: await foto(_fotoToko!, 'toko'),
        fotoRak: _fotoRak == null ? null : await foto(_fotoRak!, 'rak'),
        bukanDuplikat: bukanDuplikat,
      );

      final bisaKunjungi = hari.sudahAbsen && hari.sudahTerimaBarang && !hari.sudahKembali && hari.kunjunganTerbuka == null;
      if (!bisaKunjungi) {
        nav.pop();
        if (mounted) tampilkanInfo(context, 'Outlet baru tersimpan, menunggu verifikasi.');
        return;
      }

      final k = await hari.checkinOutlet(outletBaruRef: ref, nama: _nama.text.trim(), alamat: _alamat.text.trim(), t: t);
      await nav.pushReplacement(MaterialPageRoute(builder: (_) => KunjunganScreen(kunjungan: k)));
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'possible_duplicate') {
        setState(() => _proses = false);
        if (await _konfirmasiDuplikat(e) == true && mounted) await _simpan(hari, bukanDuplikat: true);
        return;
      }
      tampilkanGalat(context, e);
    } catch (e) {
      if (mounted) tampilkanGalat(context, e);
    } finally {
      if (mounted) setState(() => _proses = false);
    }
  }

  Future<bool?> _konfirmasiDuplikat(ApiException e) {
    final calon = (e.fields['candidates'] as List? ?? []).cast<Map>();
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kemungkinan outlet sama'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(e.message),
            const SizedBox(height: 8),
            for (final c in calon)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('• ${c['name']} (${Fmt.jarak(c['distance_m'] as num?)})${c['is_new'] == true ? ' · NOO' : ''}'),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Outlet berbeda, simpan')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hari = context.watch<Hari>();
    final t = _titik;

    return Scaffold(
      body: Column(
        children: [
          const HeaderBiru(judul: 'Outlet baru (NOO)'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(child: FotoKotak(label: 'Foto depan toko', path: _fotoToko, onFoto: (p) => setState(() => _fotoToko = p))),
                    const SizedBox(width: 12),
                    Expanded(child: FotoKotak(label: 'Foto rak produk', path: _fotoRak, onFoto: (p) => setState(() => _fotoRak = p))),
                  ],
                ),
                const SizedBox(height: 12),
                Kartu(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(controller: _nama, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Nama outlet *')),
                      const SizedBox(height: 12),
                      TextField(controller: _pemilik, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Nama pemilik')),
                      const SizedBox(height: 12),
                      TextField(controller: _hp, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'No. HP')),
                      const SizedBox(height: 12),
                      const Text('Tipe outlet', style: TextStyle(fontSize: 13, color: Warna.redup)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final tipe in hari.tipeOutlet)
                            ChoiceChip(label: Text(tipe), selected: _tipe == tipe, onSelected: (_) => setState(() => _tipe = tipe)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(controller: _alamat, maxLines: 2, decoration: const InputDecoration(labelText: 'Alamat')),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Kartu(
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_outlined, color: Warna.tautan),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Lokasi dari GPS', style: TextStyle(fontSize: 12, color: Warna.redup)),
                            Text(
                              t == null
                                  ? (_galatLokasi ?? 'Mencari lokasi…')
                                  : '${t.lat.toStringAsFixed(4)}, ${t.lng.toStringAsFixed(4)} · ± ${t.akurasi.round()} m',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      IconButton(onPressed: _lokasi, icon: const Icon(Icons.my_location), tooltip: 'Perbarui lokasi'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Catatan(
                  'Berdiri di depan toko saat menyimpan. Outlet tercatat sebagai NOO dan diverifikasi di Enesis. '
                  'Enesis menolak outlet yang terlalu dekat dengan outlet lain (kemungkinan duplikat).',
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: TombolUtama(
                hari.sudahTerimaBarang && !hari.sudahKembali ? 'Simpan & checkin outlet' : 'Simpan outlet',
                ikon: Icons.add_business,
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
