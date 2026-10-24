import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/local_db.dart';
import '../../data/hari.dart';
import '../theme.dart';
import '../widgets/umum.dart';

/// 09 Kinerja bulan ini: total Call/EC/omset/poin, perkiraan insentif, rekap harian.
class KinerjaScreen extends StatefulWidget {
  const KinerjaScreen({super.key});

  @override
  State<KinerjaScreen> createState() => _KinerjaScreenState();
}

class _KinerjaScreenState extends State<KinerjaScreen> {
  Map<String, dynamic>? _data;
  String? _galat;
  bool _muat = false;

  String get _bulan {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _ambil();
  }

  Future<void> _ambil() async {
    final hari = context.read<Hari>();
    final LocalDb local = hari.local;
    setState(() {
      _muat = true;
      _galat = null;
    });
    _data ??= await local.read('kinerja:$_bulan') as Map<String, dynamic>?;
    try {
      final res = await hari.api.get('me/performance', query: {'month': _bulan});
      _data = Map<String, dynamic>.from(res.data as Map);
      await local.write('kinerja:$_bulan', _data);
    } on ApiException catch (e) {
      _galat = e.bolehDiulang ? 'Offline · menampilkan data terakhir' : e.message;
    } finally {
      if (mounted) setState(() => _muat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final total = d?['totals'] as Map? ?? {};
    final insentif = d?['incentive_estimate'] as Map? ?? {};
    final hariHari = (d?['days'] as List? ?? []).cast<Map>();

    return Column(
      children: [
        HeaderBiru(
          judul: 'Kinerja ${Fmt.bulanTahun(DateTime.now())}',
          subjudul: '${hariHari.length} hari aktif',
          aksi: IconButton(onPressed: _muat ? null : _ambil, icon: const Icon(Icons.refresh, color: Colors.white)),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _ambil,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_galat != null) ...[Catatan(_galat!, jenis: JenisCatatan.peringatan), const SizedBox(height: 12)],
                if (d == null && _muat) const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
                if (d != null) ...[
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.9,
                    children: [
                      _kotak('Call', Fmt.ribuan(total['call'] as num? ?? 0)),
                      _kotak('Effective Call', Fmt.ribuan(total['ec'] as num? ?? 0)),
                      _kotak('Omset', Fmt.ringkas(total['sales_amount'] as num? ?? 0)),
                      _kotak('Poin', Fmt.ribuan(total['points'] as num? ?? 0)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Kartu(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Perkiraan insentif', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        BarisInfo('Insentif EC bulanan', insentif['ec_incentive'] == null ? '-' : Fmt.rupiah(insentif['ec_incentive'] as num)),
                        BarisInfo('Nilai poin', insentif['points_value'] == null ? '-' : Fmt.rupiah(insentif['points_value'] as num)),
                        const SizedBox(height: 4),
                        Text('${insentif['note'] ?? ''}', style: const TextStyle(fontSize: 12, color: Warna.redup)),
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
                          child: Row(children: [
                            Expanded(flex: 2, child: Text('Tanggal', style: TextStyle(fontSize: 12, color: Warna.redup))),
                            Expanded(child: Text('Call', textAlign: TextAlign.end, style: TextStyle(fontSize: 12, color: Warna.redup))),
                            Expanded(child: Text('EC', textAlign: TextAlign.end, style: TextStyle(fontSize: 12, color: Warna.redup))),
                            Expanded(flex: 2, child: Text('Omset', textAlign: TextAlign.end, style: TextStyle(fontSize: 12, color: Warna.redup))),
                          ]),
                        ),
                        for (final h in hariHari.reversed)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            child: Row(children: [
                              Expanded(flex: 2, child: Text(_tgl('${h['date']}'))),
                              Expanded(child: Text('${h['call']}', textAlign: TextAlign.end)),
                              Expanded(child: Text('${h['ec']}', textAlign: TextAlign.end)),
                              Expanded(flex: 2, child: Text(Fmt.ringkas(h['sales_amount'] as num? ?? 0), textAlign: TextAlign.end)),
                            ]),
                          ),
                        if (hariHari.isEmpty)
                          const Padding(padding: EdgeInsets.all(16), child: Text('Belum ada data bulan ini.', style: TextStyle(color: Warna.redup))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Catatan('Angka dihitung Enesis dari data yang sudah tersinkron.'),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _tgl(String ymd) {
    final t = DateTime.tryParse(ymd);
    return t == null ? ymd : Fmt.tanggal(t).split(', ').last;
  }

  Widget _kotak(String label, String nilai) => Kartu(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Warna.redup)),
            Text(nilai, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}
