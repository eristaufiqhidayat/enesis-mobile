import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/format.dart';
import '../../../data/koordinator.dart';
import '../../theme.dart';
import '../../widgets/umum.dart';
import 'join_visit_mulai_screen.dart';
import 'join_visit_selesai_screen.dart';

/// Join visit hari ini (berjalan dan selesai). Data yang sama tampil di web menu Join Visit.
class RiwayatJoinVisitScreen extends StatelessWidget {
  const RiwayatJoinVisitScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final koor = context.watch<Koordinator>();
    final daftar = koor.joinVisit;
    final bisaMulai = koor.sudahAbsen && !koor.sudahPulang && koor.joinVisitBerjalan == null;

    return Scaffold(
      body: Column(
        children: [
          HeaderBiru(judul: 'Join visit', subjudul: '${Fmt.tanggal(DateTime.now())} · ${koor.jumlahJoinVisitSelesai} selesai'),
          Expanded(
            child: RefreshIndicator(
              onRefresh: koor.segarkan,
              child: daftar.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(16),
                      children: const [Catatan('Belum ada join visit hari ini.')],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: daftar.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => _KartuJoinVisit(jv: daftar[i]),
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: bisaMulai
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const JoinVisitMulaiScreen())),
              icon: const Icon(Icons.add),
              label: const Text('Join visit'),
            )
          : null,
    );
  }
}

class _KartuJoinVisit extends StatelessWidget {
  const _KartuJoinVisit({required this.jv});

  final Map<String, dynamic> jv;

  @override
  Widget build(BuildContext context) {
    final selesai = jv['status'] == 'selesai';
    final mulai = Fmt.parse(jv['started_at']);
    final akhir = Fmt.parse(jv['finished_at']);
    final durasi = (jv['duration_s'] as num?) != null
        ? ((jv['duration_s'] as num) / 60).round()
        : (mulai != null && akhir != null ? akhir.difference(mulai).inMinutes : null);

    return Kartu(
      onTap: selesai ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => JoinVisitSelesaiScreen(jv: jv))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('${jv['outlet']?['name'] ?? '-'}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
              selesai
                  ? const Lencana('Selesai', latar: Warna.suksesMuda, depan: Warna.sukses)
                  : const Lencana('Berjalan', latar: Warna.biruMuda, depan: Warna.biruTua),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [
              'Bersama ${jv['sales']?['name'] ?? '-'}',
              '${Fmt.jam(mulai)}${akhir != null ? '–${Fmt.jam(akhir)}' : ''}',
              if (durasi != null) '$durasi menit',
            ].join(' · '),
            style: const TextStyle(fontSize: 12, color: Warna.redup),
          ),
          if (jv['note'] != null && '${jv['note']}'.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('${jv['note']}', style: const TextStyle(fontSize: 13)),
          ],
          if (!selesai) ...[
            const SizedBox(height: 8),
            const Text('Ketuk untuk menyelesaikan', style: TextStyle(fontSize: 12, color: Warna.tautan)),
          ],
        ],
      ),
    );
  }
}
