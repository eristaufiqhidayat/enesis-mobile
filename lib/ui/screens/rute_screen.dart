import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../data/hari.dart';
import '../theme.dart';
import '../widgets/umum.dart';
import 'kunjungan_screen.dart';
import 'outlet_baru_screen.dart';

/// 04 Rute hari ini: outlet di area sales dengan status Belum / Beli / Tidak beli.
class RuteScreen extends StatefulWidget {
  const RuteScreen({super.key});

  @override
  State<RuteScreen> createState() => _RuteScreenState();
}

class _RuteScreenState extends State<RuteScreen> {
  String _filter = 'semua';
  String _cari = '';

  @override
  Widget build(BuildContext context) {
    final hari = context.watch<Hari>();
    final semua = hari.rute;
    final status = {for (final o in semua) o['id']: hari.statusOutlet(o)};
    int hitung(String s) => status.values.where((v) => v == s).length;

    final daftar = semua.where((o) {
      final s = status[o['id']];
      final cocokFilter = switch (_filter) {
        'belum' => s == 'belum',
        'beli' => s == 'beli',
        'tidak_beli' => s == 'tidak_beli',
        _ => true,
      };
      final q = _cari.toLowerCase();
      return cocokFilter &&
          (q.isEmpty || '${o['name']} ${o['code']} ${o['address']}'.toLowerCase().contains(q));
    }).toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OutletBaruScreen())),
        icon: const Icon(Icons.add_business_outlined),
        label: const Text('Outlet baru'),
      ),
      body: Column(
        children: [
          HeaderBiru(
            judul: 'Rute hari ini',
            subjudul: '${(hari.ruteMeta['area_ids'] as List?)?.length ?? 0} area · ${semua.length} outlet',
            aksi: IconButton(
              onPressed: hari.memuat ? null : hari.segarkan,
              icon: const Icon(Icons.refresh, color: Colors.white),
              tooltip: 'Perbarui',
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              onChanged: (v) => setState(() => _cari = v),
              decoration: const InputDecoration(isDense: true, prefixIcon: Icon(Icons.search), hintText: 'Cari nama / kode outlet'),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: [
                for (final (k, label) in [
                  ('semua', 'Semua ${semua.length}'),
                  ('belum', 'Belum ${hitung('belum')}'),
                  ('beli', 'Beli ${hitung('beli')}'),
                  ('tidak_beli', 'Tidak beli ${hitung('tidak_beli')}'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _filter == k,
                      onSelected: (_) => setState(() => _filter = k),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: hari.segarkan,
              child: daftar.isEmpty
                  ? ListView(children: [
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          semua.isEmpty ? 'Rute belum dimuat. Tarik ke bawah untuk memperbarui saat online.' : 'Tidak ada outlet.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Warna.redup),
                        ),
                      ),
                    ])
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                      itemCount: daftar.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _KartuOutlet(outlet: daftar[i], status: status[daftar[i]['id']]!),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KartuOutlet extends StatelessWidget {
  const _KartuOutlet({required this.outlet, required this.status});

  final Map<String, dynamic> outlet;
  final String status;

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (outlet['code'] != null) outlet['code'],
      if (outlet['distance_m'] != null) Fmt.jarak(outlet['distance_m'] as num),
      if (outlet['address'] != null) outlet['address'],
    ].join(' · ');

    return Kartu(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onTap: status == 'belum' || status == 'dikunjungi' ? () => KunjunganScreen.checkin(context, outlet) : null,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${outlet['name'] ?? '-'}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(meta, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Warna.redup)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Lencana.status(status),
        ],
      ),
    );
  }
}
