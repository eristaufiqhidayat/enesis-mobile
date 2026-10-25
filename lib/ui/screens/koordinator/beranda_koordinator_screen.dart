import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/format.dart';
import '../../../data/koordinator.dart';
import '../../../data/session.dart';
import '../../theme.dart';
import '../../widgets/umum.dart';
import 'absen_koordinator_screen.dart';
import 'join_visit_mulai_screen.dart';
import 'join_visit_selesai_screen.dart';

/// Beranda koordinator: absen, join visit yang berjalan, dan ringkasan tim hari ini.
class BerandaKoordinatorScreen extends StatelessWidget {
  const BerandaKoordinatorScreen({super.key, required this.bukaTim, required this.bukaRiwayat});

  final VoidCallback bukaTim;
  final VoidCallback bukaRiwayat;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final koor = context.watch<Koordinator>();
    final sekarang = DateTime.now();
    final salam = sekarang.hour < 11 ? 'pagi' : (sekarang.hour < 15 ? 'siang' : (sekarang.hour < 18 ? 'sore' : 'malam'));
    final berjalan = koor.joinVisitBerjalan;
    final meta = koor.timMeta;

    return RefreshIndicator(
      onRefresh: koor.segarkan,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            color: Warna.biruTua,
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 56),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Fmt.tanggal(sekarang), style: const TextStyle(fontSize: 13, color: Warna.biruHeaderTeks)),
                const SizedBox(height: 2),
                Text('Selamat $salam, ${session.namaDepan}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _chipHeader('Koordinator'),
                    if (session.depo != null) _chipHeader('Depo ${session.depo!['name']}'),
                    if (koor.outbox.pendingCount > 0) _chipHeader('${koor.outbox.pendingCount} menunggu sinyal'),
                  ],
                ),
              ],
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -40),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _KartuAbsen(koor: koor),
                  if (koor.galatMuat != null) ...[
                    const SizedBox(height: 12),
                    Catatan(koor.galatMuat!, jenis: JenisCatatan.peringatan, ikon: Icons.cloud_off),
                  ],
                  const SizedBox(height: 12),
                  if (berjalan != null)
                    _KartuJoinVisitBerjalan(jv: berjalan)
                  else
                    Kartu(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Join visit', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text(
                            koor.sudahAbsen
                                ? 'Dampingi sales di outlet: pilih sales dan outlet di lokasi, lalu selesaikan dengan catatan dan foto.'
                                : 'Absen masuk dulu sebelum memulai join visit.',
                            style: const TextStyle(fontSize: 13, color: Warna.redup),
                          ),
                          const SizedBox(height: 12),
                          TombolUtama(
                            'Mulai join visit',
                            ikon: Icons.handshake_outlined,
                            onPressed: koor.sudahAbsen && !koor.sudahPulang
                                ? () async {
                                    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const JoinVisitMulaiScreen()));
                                  }
                                : null,
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  Kartu(
                    onTap: bukaTim,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Text('Tim hari ini', style: Theme.of(context).textTheme.titleMedium),
                            const Spacer(),
                            const Icon(Icons.chevron_right, color: Warna.redup),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _Angka('Sudah absen', '${meta['checked_in'] ?? 0} / ${meta['total'] ?? koor.tim.length}'),
                            _Angka('Kunjungan', Fmt.ribuan((meta['visits'] as num?) ?? 0)),
                            _Angka('Omzet', Fmt.ringkas((meta['sales_amount'] as num?) ?? 0)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Kartu(
                    onTap: bukaRiwayat,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        const Icon(Icons.fact_check_outlined, color: Warna.tautan),
                        const SizedBox(width: 12),
                        Expanded(child: Text('${koor.jumlahJoinVisitSelesai} join visit selesai hari ini')),
                        const Icon(Icons.chevron_right, color: Warna.redup),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _chipHeader(String teks) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: const Color(0x24FFFFFF), borderRadius: BorderRadius.circular(12)),
        child: Text(teks, style: const TextStyle(color: Colors.white, fontSize: 12)),
      );
}

class _KartuAbsen extends StatelessWidget {
  const _KartuAbsen({required this.koor});

  final Koordinator koor;

  @override
  Widget build(BuildContext context) {
    final String status;
    if (!koor.sudahAbsen) {
      status = 'Belum absen masuk';
    } else if (koor.sudahPulang) {
      status = 'Masuk ${Fmt.jam(koor.jamMasuk)} · pulang ${Fmt.jam(koor.jamPulang)}';
    } else {
      status = 'Masuk ${Fmt.jam(koor.jamMasuk)}${koor.terlambat ? ' · terlambat' : ''}';
    }

    return Kartu(
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: koor.sudahAbsen ? Warna.suksesMuda : Warna.peringatanMuda,
            child: Icon(koor.sudahAbsen ? Icons.how_to_reg : Icons.schedule, color: koor.sudahAbsen ? Warna.sukses : Warna.peringatan),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Absen', style: TextStyle(fontSize: 12, color: Warna.redup)),
                Text(status, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (!koor.sudahPulang)
            FilledButton.tonal(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AbsenKoordinatorScreen())),
              child: Text(koor.sudahAbsen ? 'Pulang' : 'Absen'),
            ),
        ],
      ),
    );
  }
}

class _KartuJoinVisitBerjalan extends StatelessWidget {
  const _KartuJoinVisitBerjalan({required this.jv});

  final Map<String, dynamic> jv;

  @override
  Widget build(BuildContext context) {
    final mulai = Fmt.parse(jv['started_at']);
    final menit = mulai == null ? null : DateTime.now().difference(mulai).inMinutes;

    return Kartu(
      warna: Warna.biruMuda,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.handshake, color: Warna.biruTua, size: 18),
              SizedBox(width: 6),
              Text('Join visit berjalan', style: TextStyle(fontWeight: FontWeight.w600, color: Warna.biruTua)),
            ],
          ),
          const SizedBox(height: 8),
          Text('${jv['outlet']?['name'] ?? '-'}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          Text('Bersama ${jv['sales']?['name'] ?? '-'} · mulai ${Fmt.jam(mulai)}${menit == null ? '' : ' ($menit menit)'}',
              style: const TextStyle(fontSize: 13, color: Warna.redup)),
          const SizedBox(height: 12),
          TombolUtama(
            'Selesaikan join visit',
            ikon: Icons.check,
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => JoinVisitSelesaiScreen(jv: jv)));
            },
          ),
        ],
      ),
    );
  }
}

class _Angka extends StatelessWidget {
  const _Angka(this.label, this.nilai);

  final String label;
  final String nilai;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Warna.redup)),
          Text(nilai, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
