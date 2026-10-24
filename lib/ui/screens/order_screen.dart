import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../data/hari.dart';
import '../theme.dart';
import '../widgets/umum.dart';

/// 06 Penjualan / order dari sisa bawaan. Total final dihitung ulang server dari harga master.
class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key, required this.kunjungan});

  final Map<String, dynamic> kunjungan;

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  final _qty = <int, num>{};
  String _cari = '';
  bool _proses = false;

  Future<void> _simpan(Hari hari) async {
    if (_qty.values.every((q) => q <= 0)) return tampilkanGalat(context, 'Pilih minimal satu produk.');

    setState(() => _proses = true);
    try {
      await hari.buatOrder(widget.kunjungan, _qty);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      tampilkanInfo(context, 'Order ${widget.kunjungan['nama']} tersimpan.');
    } catch (e) {
      if (mounted) tampilkanGalat(context, e);
    } finally {
      if (mounted) setState(() => _proses = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hari = context.watch<Hari>();
    final master = hari.produkById;
    final bawaan = hari.bawaan;
    final q = _cari.toLowerCase();
    final daftar = bawaan.where((b) => q.isEmpty || '${b['name']} ${b['code']}'.toLowerCase().contains(q)).toList();

    final harga = {for (final b in bawaan) (b['product_id'] as num).toInt(): (b['price'] as num?) ?? 0};
    final dipilih = _qty.entries.where((e) => e.value > 0).toList();
    final total = dipilih.fold<num>(0, (a, e) => a + e.value * (harga[e.key] ?? 0));
    final item = dipilih.fold<num>(0, (a, e) => a + e.value);
    final minimal = hari.minimalTransaksi;

    return Scaffold(
      body: Column(
        children: [
          HeaderBiru(judul: 'Order', subjudul: '${widget.kunjungan['nama']}'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              onChanged: (v) => setState(() => _cari = v),
              decoration: const InputDecoration(isDense: true, prefixIcon: Icon(Icons.search), hintText: 'Cari produk'),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: daftar.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final b = daftar[i];
                final id = (b['product_id'] as num).toInt();
                final sisa = (b['qty_remaining'] as num?) ?? 0;
                final fokus = master[id]?['is_focus'] == true;
                return Kartu(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${b['name']}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                            Text('${Fmt.rupiah(b['price'] as num?)} · sisa bawaan ${Fmt.qty(sisa)}',
                                style: const TextStyle(fontSize: 12, color: Warna.redup)),
                            if (fokus) ...[
                              const SizedBox(height: 4),
                              const Lencana('Produk fokus', latar: Warna.peringatanMuda, depan: Warna.peringatan),
                            ],
                          ],
                        ),
                      ),
                      StepperQty(
                        nilai: _qty[id] ?? 0,
                        maks: sisa,
                        onUbah: (v) => setState(() => _qty[id] = v),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Material(
            color: Colors.white,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text('${dipilih.length} SKU · ${Fmt.qty(item)} item', style: const TextStyle(color: Warna.redup))),
                        const Text('Total', style: TextStyle(color: Warna.redup)),
                        const SizedBox(width: 8),
                        Text(Fmt.rupiah(total), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    total >= minimal
                        ? Catatan('Di atas minimal ${Fmt.rupiah(minimal)} (Effective Call)', jenis: JenisCatatan.sukses)
                        : Catatan('Di bawah minimal ${Fmt.rupiah(minimal)}: order tetap tersimpan tetapi tidak dihitung EC.',
                            jenis: JenisCatatan.peringatan),
                    const SizedBox(height: 12),
                    TombolUtama('Simpan order & checkout outlet', proses: _proses, onPressed: () => _simpan(hari)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
