import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../data/hari.dart';
import '../../data/lokasi.dart';
import '../theme.dart';
import '../widgets/umum.dart';

/// 08 Pengembalian & checkout: bawa = terjual + kembali per SKU, uang tunai untuk disetor.
class TutupHariScreen extends StatefulWidget {
  const TutupHariScreen({super.key});

  @override
  State<TutupHariScreen> createState() => _TutupHariScreenState();
}

class _TutupHariScreenState extends State<TutupHariScreen> {
  bool _selisih = false;
  bool _proses = false;
  final _kembali = <int, num>{};
  final _alasan = <int, TextEditingController>{};

  @override
  void dispose() {
    for (final c in _alasan.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _tutup(Hari hari) async {
    final buka = hari.kunjunganTerbuka;
    if (buka != null) return tampilkanGalat(context, 'Selesaikan kunjungan ${buka['nama']} dulu.');

    final berselisih = <int, (num, String)>{};
    for (final b in hari.bawaan) {
      final id = (b['product_id'] as num).toInt();
      final sisa = (b['qty_remaining'] as num?) ?? 0;
      final q = _kembali[id];
      if (q != null && q != sisa) {
        final alasan = _alasan[id]?.text.trim() ?? '';
        if (alasan.isEmpty) return tampilkanGalat(context, 'Isi alasan selisih untuk ${b['name']}.');
        berselisih[id] = (q, alasan);
      }
    }

    final yakin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tutup hari?'),
        content: const Text('Sisa barang diserahkan ke staf depo, lalu checkout depo dan absen pulang. Setelah ini tidak bisa kunjungan lagi hari ini.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Tutup hari')),
        ],
      ),
    );
    if (yakin != true || !mounted) return;

    setState(() => _proses = true);
    try {
      Titik? t;
      try {
        t = await Lokasi.sekarang();
      } on LokasiException {
        t = null; // lokasi opsional untuk checkout
      }
      final antri = await hari.tutupHari(berselisih, t);
      if (!mounted) return;
      Navigator.of(context).pop();
      tampilkanHasil(context, antri, 'Hari ini ditutup. Terima kasih!');
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
    final k = hari.kpi;
    num jumlah(String f) => items.fold<num>(0, (a, i) => a + ((i[f] as num?) ?? 0));
    final kembaliTotal = items.fold<num>(0, (a, i) => a + (_kembali[(i['product_id'] as num).toInt()] ?? (i['qty_remaining'] as num? ?? 0)));

    const kepala = TextStyle(fontSize: 12, color: Warna.redup);

    return Scaffold(
      body: Column(
        children: [
          HeaderBiru(judul: 'Tutup hari', subjudul: c == null ? null : '${c['number']} · Depo ${hari.depo['name'] ?? '-'}'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(child: _ringkas('Call', '${k['call']} / ${hari.ruteMeta['total'] ?? hari.rute.length}')),
                    const SizedBox(width: 8),
                    Expanded(child: _ringkas('EC', '${k['ec']}')),
                    const SizedBox(width: 8),
                    Expanded(child: _ringkas('Omset', Fmt.ringkas(k['omset'] ?? 0))),
                  ],
                ),
                const SizedBox(height: 12),
                Kartu(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                        child: Row(children: [
                          Expanded(flex: 3, child: Text('Produk', style: kepala)),
                          Expanded(child: Text('Bawa', textAlign: TextAlign.end, style: kepala)),
                          Expanded(child: Text('Terjual', textAlign: TextAlign.end, style: kepala)),
                          Expanded(flex: 2, child: Text('Kembali', textAlign: TextAlign.end, style: kepala)),
                        ]),
                      ),
                      for (final i in items) _baris(i),
                      const Divider(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(children: [
                          const Expanded(flex: 3, child: Text('Total', style: TextStyle(fontWeight: FontWeight.w600))),
                          Expanded(child: Text(Fmt.qty(jumlah('qty_carried')), textAlign: TextAlign.end)),
                          Expanded(child: Text(Fmt.qty(jumlah('qty_sold')), textAlign: TextAlign.end)),
                          Expanded(flex: 2, child: Text(Fmt.qty(kembaliTotal), textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w600))),
                        ]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => setState(() => _selisih = !_selisih),
                    child: Text(_selisih ? 'Selesai ubah' : 'Jumlah kembali berbeda?'),
                  ),
                ),
                const Catatan('Bawa = terjual + kembali untuk semua SKU. Staf depo mencocokkan fisik sisa barang.'),
                const SizedBox(height: 12),
                Kartu(
                  child: Row(
                    children: [
                      const Expanded(child: Text('Uang tunai untuk disetor', style: TextStyle(color: Warna.redup))),
                      Text(Fmt.rupiah(hari.totalPenjualan), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: TombolUtama(
                'Serahkan sisa & checkout depo',
                ikon: Icons.assignment_turned_in,
                proses: _proses,
                onPressed: hari.sudahTutup ? null : () => _tutup(hari),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ringkas(String label, String nilai) => Kartu(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Warna.redup)),
            Text(nilai, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        ),
      );

  Widget _baris(Map<String, dynamic> i) {
    final id = (i['product_id'] as num).toInt();
    final sisa = (i['qty_remaining'] as num?) ?? 0;
    final q = _kembali[id] ?? sisa;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(flex: 3, child: Text('${i['name']}', style: const TextStyle(fontSize: 13))),
              Expanded(child: Text(Fmt.qty(i['qty_carried'] as num?), textAlign: TextAlign.end)),
              Expanded(child: Text(Fmt.qty(i['qty_sold'] as num?), textAlign: TextAlign.end)),
              Expanded(
                flex: 2,
                child: _selisih
                    ? FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerRight, child: StepperQty(nilai: q, maks: i['qty_carried'] as num?, onUbah: (v) => setState(() => _kembali[id] = v)))
                    : Text(Fmt.qty(q), textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          if (q != sisa)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: TextField(
                controller: _alasan.putIfAbsent(id, TextEditingController.new),
                decoration: InputDecoration(isDense: true, labelText: 'Alasan selisih (seharusnya ${Fmt.qty(sisa)})'),
              ),
            ),
        ],
      ),
    );
  }
}
