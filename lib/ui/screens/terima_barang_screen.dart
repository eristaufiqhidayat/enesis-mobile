import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../data/hari.dart';
import '../theme.dart';
import '../widgets/umum.dart';

/// 03 Terima barang canvassing: periksa jumlah fisik; selisih dilaporkan sekarang.
class TerimaBarangScreen extends StatefulWidget {
  const TerimaBarangScreen({super.key});

  @override
  State<TerimaBarangScreen> createState() => _TerimaBarangScreenState();
}

class _TerimaBarangScreenState extends State<TerimaBarangScreen> {
  bool _selisih = false;
  bool _proses = false;
  final _qty = <int, num>{};
  final _alasan = <int, TextEditingController>{};

  @override
  void dispose() {
    for (final c in _alasan.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _terima(Hari hari) async {
    final berselisih = <int, (num, String)>{};

    for (final i in hari.bawaan) {
      final id = (i['product_id'] as num).toInt();
      final disiapkan = i['qty_prepared'] as num;
      final q = _qty[id];
      if (q != null && q != disiapkan) {
        final alasan = _alasan[id]?.text.trim() ?? '';
        if (alasan.isEmpty) return tampilkanGalat(context, 'Isi alasan selisih untuk ${i['name']}.');
        berselisih[id] = (q, alasan);
      }
    }

    setState(() => _proses = true);
    try {
      final antri = await hari.terimaBarang(berselisih);
      if (!mounted) return;
      Navigator.of(context).pop();
      tampilkanHasil(context, antri, 'Barang canvassing diterima.');
    } catch (e) {
      if (mounted) tampilkanGalat(context, e);
    } finally {
      if (mounted) setState(() => _proses = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hari = context.watch<Hari>();
    final c = hari.canvassing;
    final items = hari.bawaan;
    final totalQty = items.fold<num>(0, (a, i) => a + ((i['qty_prepared'] as num?) ?? 0));

    if (c == null) {
      return Scaffold(
        body: Column(
          children: [
            const HeaderBiru(judul: 'Terima barang canvassing'),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 48, color: Warna.redup),
                      const SizedBox(height: 12),
                      const Text('Muatan hari ini belum disiapkan staf depo.', textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: hari.memuat ? null : hari.segarkan,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Periksa lagi'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          const HeaderBiru(judul: 'Terima barang canvassing'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Kartu(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('No. canvassing', style: TextStyle(fontSize: 12, color: Warna.redup)),
                      Text('${c['number']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: _angka('SKU', '${items.length}')),
                          Expanded(child: _angka('Total qty', Fmt.qty(totalQty))),
                          Expanded(child: _angka('Status', '${c['status']}')),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Kartu(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                        child: Row(
                          children: [
                            Expanded(child: Text('Produk', style: TextStyle(fontSize: 12, color: Warna.redup))),
                            Text('Dibawa', style: TextStyle(fontSize: 12, color: Warna.redup)),
                          ],
                        ),
                      ),
                      for (final i in items) _baris(i),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Catatan('Periksa jumlah fisik sebelum menekan Terima. Selisih dilaporkan ke staf depo sekarang, bukan saat pengembalian.'),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _selisih = !_selisih),
                      child: Text(_selisih ? 'Batal selisih' : 'Laporkan selisih'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: TombolUtama('Terima barang', proses: _proses, onPressed: () => _terima(hari))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _angka(String label, String nilai) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Warna.redup)),
          Text(nilai, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      );

  Widget _baris(Map<String, dynamic> i) {
    final id = (i['product_id'] as num).toInt();
    final disiapkan = i['qty_prepared'] as num;
    final q = _qty[id] ?? disiapkan;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${i['name'] ?? 'Produk ${i['product_id']}'}', style: const TextStyle(fontWeight: FontWeight.w500)),
                    if (i['code'] != null) Text('${i['code']}', style: const TextStyle(fontSize: 12, color: Warna.redup)),
                  ],
                ),
              ),
              if (_selisih)
                StepperQty(nilai: q, onUbah: (v) => setState(() => _qty[id] = v))
              else
                Text(Fmt.qty(disiapkan), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
          if (_selisih && q != disiapkan)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextField(
                controller: _alasan.putIfAbsent(id, TextEditingController.new),
                decoration: InputDecoration(
                  isDense: true,
                  labelText: 'Alasan selisih (disiapkan ${Fmt.qty(disiapkan)})',
                ),
              ),
            ),
        ],
      ),
    );
  }
}
