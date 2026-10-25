import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/format.dart';
import '../../../data/koordinator.dart';
import '../../theme.dart';
import '../../widgets/umum.dart';
import 'join_visit_mulai_screen.dart';

/// Tim hari ini: sales bawahan beserta absen, kunjungan, penjualan, dan posisi GPS terakhir.
class TimScreen extends StatelessWidget {
  const TimScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final koor = context.watch<Koordinator>();
    final meta = koor.timMeta;
    final bisaJoin = koor.sudahAbsen && !koor.sudahPulang && koor.joinVisitBerjalan == null;

    return Column(
      children: [
        HeaderBiru(
          judul: 'Tim hari ini',
          subjudul: '${meta['checked_in'] ?? 0} dari ${meta['total'] ?? koor.tim.length} sales sudah absen',
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: koor.segarkan,
            child: koor.tim.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Catatan(koor.memuat ? 'Memuat tim…' : 'Belum ada sales aktif di tim Anda. Hubungi admin bila ini keliru.'),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: koor.tim.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _KartuSales(
                      s: koor.tim[i],
                      onJoin: bisaJoin
                          ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => JoinVisitMulaiScreen(sales: koor.tim[i])))
                          : null,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _KartuSales extends StatelessWidget {
  const _KartuSales({required this.s, this.onJoin});

  final Map<String, dynamic> s;
  final VoidCallback? onJoin;

  @override
  Widget build(BuildContext context) {
    final absen = s['attendance'] as Map?;
    final posisi = s['last_position'] as Map?;
    final Lencana status;
    if (absen == null) {
      status = const Lencana('Belum absen', latar: Warna.bahayaMuda, depan: Warna.bahaya);
    } else if (absen['checked_out_at'] != null) {
      status = const Lencana('Sudah pulang', latar: Warna.jalur, depan: Warna.redup);
    } else if (s['visit_open'] == true) {
      status = const Lencana('Di outlet', latar: Warna.suksesMuda, depan: Warna.sukses);
    } else {
      status = const Lencana('Bekerja', latar: Warna.biruMuda, depan: Warna.biruTua);
    }

    return Kartu(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('${s['name']}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
              status,
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [
              if (absen != null) 'Masuk ${Fmt.jam(Fmt.parse(absen['checked_in_at']))}${absen['is_late'] == true ? ' (terlambat)' : ''}',
              if (posisi != null) 'GPS ${Fmt.jam(Fmt.parse(posisi['at']))}',
              if (s['phone'] != null) '${s['phone']}',
            ].join(' · '),
            style: const TextStyle(fontSize: 12, color: Warna.redup),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _Nilai('Kunjungan', Fmt.ribuan((s['visits'] as num?) ?? 0)),
              _Nilai('EC', Fmt.ribuan((s['ec'] as num?) ?? 0)),
              _Nilai('Omzet', Fmt.rupiah((s['sales_amount'] as num?) ?? 0)),
            ],
          ),
          if (onJoin != null && absen != null && absen['checked_out_at'] == null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(onPressed: onJoin, icon: const Icon(Icons.handshake_outlined, size: 18), label: const Text('Join visit')),
            ),
          ],
        ],
      ),
    );
  }
}

class _Nilai extends StatelessWidget {
  const _Nilai(this.label, this.nilai);

  final String label;
  final String nilai;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Warna.redup)),
          Text(nilai, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
