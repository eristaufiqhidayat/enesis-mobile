import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../data/hari.dart';
import '../../data/lokasi.dart';
import '../theme.dart';
import '../widgets/umum.dart';
import 'order_screen.dart';

/// 05 Kunjungan outlet: stok sendiri & kompetitor, lalu Tidak beli atau Buat order.
class KunjunganScreen extends StatefulWidget {
  const KunjunganScreen({super.key, required this.kunjungan});

  final Map<String, dynamic> kunjungan;

  /// Checkin ke outlet (dari Rute / Beranda): cek syarat hari, ambil GPS, cek jarak, catat kunjungan.
  static Future<void> checkin(BuildContext context, Map<String, dynamic> outlet) async {
    final hari = context.read<Hari>();
    final nav = Navigator.of(context);
    final buka = hari.kunjunganTerbuka;

    if (buka != null) {
      if (buka['outlet_id'] == outlet['id']) {
        await nav.push(MaterialPageRoute(builder: (_) => KunjunganScreen(kunjungan: buka)));
      } else {
        tampilkanGalat(context, 'Selesaikan kunjungan ${buka['nama']} dulu.');
      }
      return;
    }
    if (!hari.sudahAbsen) return tampilkanGalat(context, 'Absen masuk dulu.');
    if (!hari.sudahTerimaBarang) return tampilkanGalat(context, 'Terima barang canvassing dulu.');
    if (hari.sudahKembali) return tampilkanGalat(context, 'Sisa barang sudah dikembalikan; kunjungan hari ini ditutup.');

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(children: [CircularProgressIndicator(), SizedBox(width: 16), Expanded(child: Text('Mengambil lokasi…'))]),
      ),
    );

    try {
      final t = await Lokasi.sekarang();
      nav.pop();
      if (!context.mounted) return;
      if (t.palsu) return tampilkanGalat(context, 'Lokasi palsu (mock location) terdeteksi.');

      final lat = outlet['lat'] as num?;
      final lng = outlet['lng'] as num?;
      final batas = (hari.config['outlet_radius_m'] as num?) ?? 100;
      if (lat != null && lng != null) {
        final jarak = t.jarakKe(lat.toDouble(), lng.toDouble());
        if (jarak > batas) {
          return tampilkanGalat(context, 'Anda ${jarak.round()} m dari outlet, batas ${batas.round()} m.');
        }
      }

      final k = await hari.checkinOutlet(
        outletId: (outlet['id'] as num).toInt(),
        nama: '${outlet['name']}',
        kode: outlet['code'] as String?,
        alamat: outlet['address'] as String?,
        t: t,
      );
      await nav.push(MaterialPageRoute(builder: (_) => KunjunganScreen(kunjungan: k)));
    } catch (e) {
      if (nav.canPop()) nav.popUntil((r) => r is! DialogRoute);
      if (context.mounted) tampilkanGalat(context, e);
    }
  }

  @override
  State<KunjunganScreen> createState() => _KunjunganScreenState();
}

class _KunjunganScreenState extends State<KunjunganScreen> {
  final _stok = <int, num>{};
  final _kompetitor = <String, num>{};
  bool _proses = false;

  Future<void> _simpanStok(Hari hari) async {
    if (_stok.isEmpty && _kompetitor.isEmpty) return;
    await hari.simpanStok(widget.kunjungan, _stok, _kompetitor);
  }

  Future<void> _tidakBeli(Hari hari) async {
    final pilihan = await showModalBottomSheet<(String, String?)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PilihAlasan(alasan: hari.alasanTidakBeli),
    );
    if (pilihan == null) return;

    setState(() => _proses = true);
    try {
      await _simpanStok(hari);
      await hari.tidakBeli(widget.kunjungan, pilihan.$1, pilihan.$2);
      if (!mounted) return;
      Navigator.of(context).pop();
      tampilkanInfo(context, 'Kunjungan ${widget.kunjungan['nama']} selesai (tidak beli).');
    } catch (e) {
      if (mounted) tampilkanGalat(context, e);
    } finally {
      if (mounted) setState(() => _proses = false);
    }
  }

  Future<void> _order(Hari hari) async {
    try {
      await _simpanStok(hari);
    } catch (e) {
      if (mounted) tampilkanGalat(context, e);
      return;
    }
    if (!mounted) return;
    final selesai = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => OrderScreen(kunjungan: widget.kunjungan)));
    if (selesai == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final hari = context.watch<Hari>();
    final k = widget.kunjungan;
    final produk = hari.bawaan;
    final kompetitor = hari.kompetitor;

    return Scaffold(
      body: Column(
        children: [
          HeaderBiru(
            judul: '${k['nama']}',
            subjudul: [if (k['kode'] != null) k['kode'], if (k['luar_rute'] == true) 'Di luar rute'].join(' · ').ifEmptyNull,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Kartu(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(spacing: 8, children: [
                        Lencana('Checkin ${Fmt.jam(Fmt.parse(k['checkin_at']))}', latar: Warna.suksesMuda, depan: Warna.sukses),
                        if (k['jarak_m'] != null) Lencana('${Fmt.jarak(k['jarak_m'] as num)} dari titik outlet'),
                      ]),
                      if (k['alamat'] != null) ...[
                        const SizedBox(height: 8),
                        Text('${k['alamat']}', style: const TextStyle(fontSize: 13, color: Warna.redup)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Kartu(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Stok di outlet', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      for (final p in produk)
                        _BarisStok(
                          nama: '${p['name']}',
                          nilai: _stok[(p['product_id'] as num).toInt()] ?? 0,
                          onUbah: (v) => setState(() => _stok[(p['product_id'] as num).toInt()] = v),
                        ),
                      const SizedBox(height: 8),
                      const Catatan('Stok 0 akan tercatat sebagai Out of Stock (OSS).'),
                    ],
                  ),
                ),
                if (kompetitor.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Kartu(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Stok kompetitor', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        for (final p in kompetitor)
                          _BarisStok(
                            nama: '${p['name']}',
                            nilai: _kompetitor['${p['name']}'] ?? 0,
                            onUbah: (v) => setState(() => _kompetitor['${p['name']}'] = v),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: _proses ? null : () => _tidakBeli(hari), child: const Text('Tidak beli'))),
                  const SizedBox(width: 12),
                  Expanded(child: TombolUtama('Buat order', ikon: Icons.shopping_cart_outlined, proses: _proses, onPressed: () => _order(hari))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarisStok extends StatelessWidget {
  const _BarisStok({required this.nama, required this.nilai, required this.onUbah});

  final String nama;
  final num nilai;
  final ValueChanged<num> onUbah;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(nama)),
          StepperQty(nilai: nilai, onUbah: onUbah),
        ],
      ),
    );
  }
}

/// Lembar pilihan alasan tidak beli (+ keterangan untuk "Lainnya").
class _PilihAlasan extends StatefulWidget {
  const _PilihAlasan({required this.alasan});

  final List<Map<String, dynamic>> alasan;

  @override
  State<_PilihAlasan> createState() => _PilihAlasanState();
}

class _PilihAlasanState extends State<_PilihAlasan> {
  String? _kode;
  final _catatan = TextEditingController();

  @override
  void dispose() {
    _catatan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final perluCatatan = _kode == 'lainnya';

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Alasan tidak beli', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in widget.alasan)
                ChoiceChip(
                  label: Text('${a['label']}'),
                  selected: _kode == a['code'],
                  onSelected: (_) => setState(() => _kode = a['code'] as String),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _catatan,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: perluCatatan ? 'Keterangan (wajib)' : 'Keterangan (opsional)'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _kode == null || (perluCatatan && _catatan.text.trim().isEmpty)
                ? null
                : () => Navigator.of(context).pop((_kode!, _catatan.text.trim())),
            child: const Text('Simpan & checkout outlet'),
          ),
        ],
      ),
    );
  }
}

extension on String {
  String? get ifEmptyNull => isEmpty ? null : this;
}
