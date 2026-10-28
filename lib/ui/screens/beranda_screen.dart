import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/outbox.dart';
import '../../data/hari.dart';
import '../../data/session.dart';
import '../theme.dart';
import '../widgets/umum.dart';
import 'absen_screen.dart';
import 'checkin_depo_screen.dart';
import 'kunjungan_screen.dart';
import 'terima_barang_screen.dart';
import 'tutup_hari_screen.dart';

/// 01 Beranda motoris: 5 langkah hari ini, KPI vs target, poin, dan aksi berikutnya.
class BerandaScreen extends StatelessWidget {
  const BerandaScreen({super.key, required this.bukaRute});

  final VoidCallback bukaRute;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final hari = context.watch<Hari>();
    final sekarang = DateTime.now();
    final salam = sekarang.hour < 11 ? 'pagi' : (sekarang.hour < 15 ? 'siang' : (sekarang.hour < 18 ? 'sore' : 'malam'));
    final langkah = hari.langkah;
    final selesai = langkah.where((l) => l.$2).length;

    return RefreshIndicator(
      onRefresh: hari.segarkan,
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
                    if (session.depo != null) _chipHeader('Depo ${session.depo!['name']}'),
                    if (session.koordinator != null) _chipHeader('SK: ${session.koordinator!['name']}'),
                    const _ChipSinkron(),
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
                  Kartu(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Text('Hari ini', style: Theme.of(context).textTheme.titleMedium),
                            const Spacer(),
                            Text('$selesai dari 5 langkah', style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                        const SizedBox(height: 12),
                        for (final (i, l) in langkah.indexed) _Langkah(nomor: i + 1, label: l.$1, selesai: l.$2, ket: l.$3, aktif: i == selesai),
                      ],
                    ),
                  ),
                  if (hari.galatMuat != null) ...[
                    const SizedBox(height: 12),
                    Catatan(hari.galatMuat!, jenis: JenisCatatan.peringatan, ikon: Icons.cloud_off),
                  ],
                  const SizedBox(height: 12),
                  _GridKpi(hari: hari),
                  const SizedBox(height: 12),
                  Kartu(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Poin hari ini', style: TextStyle(fontSize: 12, color: Warna.redup)),
                              Text('${Fmt.ribuan(hari.kpi['poin'] ?? 0)} poin',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        if ((hari.kpi['poin'] ?? 0) == 0)
                          const Text('Aturan poin menyusul', style: TextStyle(fontSize: 12, color: Warna.redup)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _AksiBerikutnya(hari: hari, bukaRute: bukaRute),
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
        child: Text(teks, style: const TextStyle(fontSize: 12, color: Colors.white)),
      );
}

class _ChipSinkron extends StatelessWidget {
  const _ChipSinkron();

  @override
  Widget build(BuildContext context) {
    final o = context.watch<Outbox>();
    final (teks, warna) = o.failedCount > 0
        ? ('${o.failedCount} perlu diperbaiki', Warna.bahaya)
        : o.pendingCount > 0
            ? ('${o.pendingCount} menunggu kirim', Warna.peringatan)
            : ('Tersinkron ${o.lastSyncAt == null ? '' : Fmt.jam(o.lastSyncAt)}'.trim(), Warna.sukses);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: warna, borderRadius: BorderRadius.circular(12)),
      child: Text(teks, style: const TextStyle(fontSize: 12, color: Colors.white)),
    );
  }
}

class _Langkah extends StatelessWidget {
  const _Langkah({required this.nomor, required this.label, required this.selesai, required this.ket, required this.aktif});

  final int nomor;
  final String label;
  final bool selesai;
  final String ket;
  final bool aktif;

  @override
  Widget build(BuildContext context) {
    final Widget bulat = selesai
        ? Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(color: Warna.sukses, shape: BoxShape.circle),
            child: const Icon(Icons.check, size: 14, color: Colors.white),
          )
        : Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: aktif ? Warna.aksen : Warna.garis, width: 2)),
            child: Text('$nomor',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: aktif ? Warna.aksen : Warna.redup)),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          bulat,
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: aktif ? FontWeight.w600 : FontWeight.w400,
                  color: !selesai && !aktif ? Warna.redup : Warna.teks,
                )),
          ),
          if (ket.isNotEmpty && ket != '-')
            Text(ket,
                style: TextStyle(
                  fontSize: 13,
                  color: aktif ? Warna.tautan : Warna.redup,
                  fontWeight: aktif ? FontWeight.w600 : FontWeight.w400,
                )),
        ],
      ),
    );
  }
}

class _GridKpi extends StatelessWidget {
  const _GridKpi({required this.hari});

  final Hari hari;

  @override
  Widget build(BuildContext context) {
    final k = hari.kpi;
    final t = hari.target;
    num tg(String key, num cadangan) => (t[key] as num?) ?? cadangan;

    Widget kotak(String label, String nilai, String target, double rasio, {Color warna = Warna.aksen}) => Kartu(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Warna.redup)),
              const SizedBox(height: 4),
              Text.rich(TextSpan(children: [
                TextSpan(text: nilai, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                TextSpan(text: ' / $target', style: const TextStyle(fontSize: 14, color: Warna.redup)),
              ])),
              const SizedBox(height: 6),
              BarProgres(rasio, warna: warna),
            ],
          ),
        );

    final ipt = k['ipt'] ?? 0;
    final tIpt = tg('ipt', 3);

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.55,
      children: [
        kotak('Call', '${k['call']}', '${tg('call', 40)}', (k['call'] ?? 0) / tg('call', 40)),
        kotak('Effective Call', '${k['ec']}', '${tg('ec', 25)}', (k['ec'] ?? 0) / tg('ec', 25)),
        kotak('IPT (SKU / EC)', Fmt.desimal(ipt), Fmt.desimal(tIpt), ipt / tIpt,
            warna: ipt < tIpt ? Warna.peringatan : Warna.aksen),
        kotak('Omset', Fmt.ringkas(k['omset'] ?? 0), Fmt.ringkas(tg('omset', 750000)), (k['omset'] ?? 0) / tg('omset', 750000)),
      ],
    );
  }
}

/// Tombol besar sesuai langkah yang sedang berjalan.
class _AksiBerikutnya extends StatelessWidget {
  const _AksiBerikutnya({required this.hari, required this.bukaRute});

  final Hari hari;
  final VoidCallback bukaRute;

  @override
  Widget build(BuildContext context) {
    void buka(Widget layar) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => layar));

    if (!hari.sudahAbsen) {
      return _TombolBesar(ikon: Icons.how_to_reg_outlined, kecil: 'Langkah 1', besar: 'Absen masuk', onTap: () => buka(const AbsenScreen()));
    }

    if (!hari.sudahCheckinDepo) {
      return _TombolBesar(ikon: Icons.warehouse_outlined, kecil: 'Langkah 2', besar: 'Checkin depo', onTap: () => buka(const CheckinDepoScreen()));
    }

    if (!hari.sudahTerimaBarang) {
      return _TombolBesar(
        ikon: Icons.inventory_2_outlined,
        kecil: hari.canvassing == null ? 'Muatan belum disiapkan staf depo' : 'No. ${hari.canvassing!['number']}',
        besar: 'Terima barang canvassing',
        onTap: () => buka(const TerimaBarangScreen()),
      );
    }

    if (hari.sudahTutup) {
      return const Catatan('Hari ini selesai. Terima kasih!', jenis: JenisCatatan.sukses);
    }

    final terbuka = hari.kunjunganTerbuka;
    if (terbuka != null) {
      return _TombolBesar(ikon: Icons.storefront_outlined, kecil: 'Kunjungan berjalan', besar: '${terbuka['nama']}', aksi: 'Lanjut', onTap: () => buka(KunjunganScreen(kunjungan: terbuka)));
    }

    final n = hari.outletBerikutnya;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!hari.sudahKembali)
          n == null
              ? _TombolBesar(ikon: Icons.route_outlined, kecil: 'Rute hari ini', besar: 'Lihat rute', onTap: bukaRute)
              : _TombolBesar(
                  ikon: Icons.location_on_outlined,
                  kecil: 'Outlet berikutnya${n['distance_m'] == null ? '' : ' · ${Fmt.jarak(n['distance_m'] as num)}'}',
                  besar: '${n['name']}',
                  aksi: 'Checkin',
                  onTap: () => KunjunganScreen.checkin(context, n),
                ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => buka(const TutupHariScreen()),
          icon: const Icon(Icons.assignment_turned_in_outlined),
          label: const Text('Tutup hari'),
        ),
      ],
    );
  }
}

class _TombolBesar extends StatelessWidget {
  const _TombolBesar({required this.ikon, required this.kecil, required this.besar, required this.onTap, this.aksi = 'Buka'});

  final IconData ikon;
  final String kecil;
  final String besar;
  final String aksi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Kartu(
      warna: Warna.aksen,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(ikon, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(kecil, style: const TextStyle(fontSize: 12, color: Warna.biruMuda)),
                Text(besar, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
              ],
            ),
          ),
          Text(aksi, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
        ],
      ),
    );
  }
}
