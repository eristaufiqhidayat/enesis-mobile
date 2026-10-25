import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api_client.dart';
import '../../../core/format.dart';
import '../../../data/koordinator.dart';
import '../../../data/lokasi.dart';
import '../../theme.dart';
import '../../widgets/umum.dart';

/// Mulai join visit: pilih sales yang didampingi dan outlet terdekat (dalam radius outlet).
class JoinVisitMulaiScreen extends StatefulWidget {
  const JoinVisitMulaiScreen({super.key, this.sales});

  /// Sales yang dipilih dari layar Tim (opsional).
  final Map<String, dynamic>? sales;

  @override
  State<JoinVisitMulaiScreen> createState() => _JoinVisitMulaiScreenState();
}

class _JoinVisitMulaiScreenState extends State<JoinVisitMulaiScreen> {
  final _cari = TextEditingController();
  Map<String, dynamic>? _sales;
  Map<String, dynamic>? _outlet;
  Titik? _titik;
  List<Map<String, dynamic>> _outletDekat = [];
  String? _galat;
  bool _memuat = false;
  bool _proses = false;

  @override
  void initState() {
    super.initState();
    _sales = widget.sales;
    _muatOutlet();
  }

  @override
  void dispose() {
    _cari.dispose();
    super.dispose();
  }

  Future<void> _muatOutlet() async {
    final koor = context.read<Koordinator>();
    setState(() {
      _memuat = true;
      _galat = null;
    });
    try {
      final t = await Lokasi.sekarang();
      final daftar = await koor.outletTerdekat(t, cari: _cari.text);
      if (!mounted) return;
      setState(() {
        _titik = t;
        _outletDekat = daftar;
        if (_outlet != null && daftar.every((o) => o['id'] != _outlet!['id'])) _outlet = null;
      });
    } on LokasiException catch (e) {
      if (mounted) setState(() => _galat = e.message);
    } on ApiException catch (e) {
      if (mounted) setState(() => _galat = e.bolehDiulang ? 'Butuh sinyal untuk mencari outlet terdekat. Coba lagi.' : e.message);
    } finally {
      if (mounted) setState(() => _memuat = false);
    }
  }

  Future<void> _mulai(Koordinator koor) async {
    final sales = _sales;
    final outlet = _outlet;
    final t = _titik;
    if (sales == null) return tampilkanGalat(context, 'Pilih sales yang didampingi.');
    if (outlet == null) return tampilkanGalat(context, 'Pilih outlet.');
    if (t == null) return tampilkanGalat(context, 'Lokasi belum didapat.');
    if (t.palsu) return tampilkanGalat(context, 'Lokasi palsu (mock location) terdeteksi. Matikan aplikasi pengubah lokasi.');

    final jarak = (outlet['distance_m'] as num?) ?? 0;
    if (jarak > koor.radiusOutlet) {
      return tampilkanGalat(context, 'Anda ${jarak.round()} m dari outlet, batas ${koor.radiusOutlet} m.');
    }

    setState(() => _proses = true);
    try {
      final antri = await koor.mulaiJoinVisit(sales, outlet, t);
      if (!mounted) return;
      Navigator.of(context).pop();
      tampilkanHasil(context, antri, 'Join visit dimulai di ${outlet['name']}.');
    } catch (e) {
      if (mounted) tampilkanGalat(context, e);
    } finally {
      if (mounted) setState(() => _proses = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final koor = context.watch<Koordinator>();
    final salesAktif = koor.tim.where((s) => s['attendance'] != null && (s['attendance'] as Map)['checked_out_at'] == null).toList();
    final pilihanSales = salesAktif.isNotEmpty ? salesAktif : koor.tim;

    return Scaffold(
      body: Column(
        children: [
          const HeaderBiru(judul: 'Mulai join visit', subjudul: 'Pilih sales dan outlet di lokasi'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Kartu(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Sales yang didampingi', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      if (pilihanSales.isEmpty)
                        const Catatan('Tim belum dimuat. Tarik ke bawah di layar Tim saat ada sinyal.')
                      else
                        DropdownButtonFormField<int>(
                          value: (_sales?['id'] as num?)?.toInt(),
                          isExpanded: true,
                          decoration: const InputDecoration(hintText: 'Pilih sales'),
                          items: [
                            for (final s in pilihanSales)
                              DropdownMenuItem(
                                value: (s['id'] as num).toInt(),
                                child: Text('${s['name']}${s['visit_open'] == true ? ' · di outlet' : ''}', overflow: TextOverflow.ellipsis),
                              ),
                          ],
                          onChanged: (id) => setState(() => _sales = pilihanSales.firstWhere((s) => (s['id'] as num).toInt() == id)),
                        ),
                      if (salesAktif.isNotEmpty && salesAktif.length < koor.tim.length)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text('Hanya sales yang sudah absen dan belum pulang.', style: TextStyle(fontSize: 12, color: Warna.redup)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Kartu(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Expanded(child: Text('Outlet terdekat', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
                          IconButton(onPressed: _memuat ? null : _muatOutlet, icon: const Icon(Icons.my_location), tooltip: 'Perbarui lokasi'),
                        ],
                      ),
                      TextField(
                        controller: _cari,
                        textInputAction: TextInputAction.search,
                        decoration: const InputDecoration(hintText: 'Cari nama / kode outlet', prefixIcon: Icon(Icons.search)),
                        onSubmitted: (_) => _muatOutlet(),
                      ),
                      const SizedBox(height: 8),
                      if (_memuat)
                        const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
                      else if (_galat != null)
                        Catatan(_galat!, jenis: JenisCatatan.peringatan)
                      else if (_outletDekat.isEmpty)
                        const Catatan('Tidak ada outlet dalam 300 m. Pastikan Anda berada di outlet.')
                      else
                        for (final o in _outletDekat)
                          RadioListTile<int>(
                            contentPadding: EdgeInsets.zero,
                            value: (o['id'] as num).toInt(),
                            groupValue: (_outlet?['id'] as num?)?.toInt(),
                            onChanged: (_) => setState(() => _outlet = o),
                            title: Text('${o['name']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              [if (o['code'] != null) '${o['code']}', Fmt.jarak(o['distance_m'] as num?), if (o['address'] != null) '${o['address']}'].join(' · '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            secondary: ((o['distance_m'] as num?) ?? 0) > koor.radiusOutlet
                                ? const Lencana('Jauh', latar: Warna.peringatanMuda, depan: Warna.peringatan)
                                : null,
                          ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Catatan('Join visit hanya bisa dimulai dalam ${koor.radiusOutlet} m dari outlet.'),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: TombolUtama('Mulai join visit', ikon: Icons.play_arrow, proses: _proses, onPressed: () => _mulai(koor)),
            ),
          ),
        ],
      ),
    );
  }
}
