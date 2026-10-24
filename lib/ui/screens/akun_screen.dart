import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/outbox.dart';
import '../../data/session.dart';
import '../theme.dart';
import '../widgets/umum.dart';
import 'ganti_password_screen.dart';

/// Akun: profil, antrian kirim (transaksi yang belum terkirim / ditolak), ganti password, keluar.
class AkunScreen extends StatelessWidget {
  const AkunScreen({super.key});

  Future<void> _keluar(BuildContext context) async {
    final outbox = context.read<Outbox>();
    final session = context.read<Session>();
    final peringatan = outbox.isEmpty
        ? 'Keluar dari akun di HP ini?'
        : 'Masih ada ${outbox.entries.length} transaksi yang belum terkirim. Bila keluar sekarang, data itu HILANG. Sebaiknya tunggu sampai online dan semua terkirim.';

    final ya = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar'),
        content: Text(peringatan),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: outbox.isEmpty ? Warna.aksen : Warna.bahaya),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (ya == true) await session.logout();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final outbox = context.watch<Outbox>();

    return Column(
      children: [
        const HeaderBiru(judul: 'Akun'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Kartu(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: Warna.biruMuda,
                      child: Text(session.nama.isEmpty ? '?' : session.nama[0].toUpperCase(),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Warna.biruTua)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(session.nama, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          Text('@${session.profil?['username'] ?? ''} · Sales motoris', style: const TextStyle(fontSize: 13, color: Warna.redup)),
                          if (session.depo != null) Text('Depo ${session.depo!['name']}', style: const TextStyle(fontSize: 13, color: Warna.redup)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Kartu(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(child: Text('Antrian kirim', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
                        TextButton.icon(
                          onPressed: outbox.isEmpty ? null : () => outbox.flush(force: true),
                          icon: const Icon(Icons.sync, size: 18),
                          label: const Text('Kirim sekarang'),
                        ),
                      ],
                    ),
                    if (outbox.isEmpty)
                      Text(
                        'Semua data sudah terkirim${outbox.lastSyncAt == null ? '' : ' (${Fmt.jam(outbox.lastSyncAt)})'}.',
                        style: const TextStyle(color: Warna.redup),
                      ),
                    for (final e in outbox.entries) _BarisAntrian(entry: e),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Kartu(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.lock_outline),
                      title: const Text('Ganti password'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GantiPasswordScreen())),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.logout, color: Warna.bahaya),
                      title: const Text('Keluar', style: TextStyle(color: Warna.bahaya)),
                      onTap: () => _keluar(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Enesis Motoris v${AppConfig.appVersion}', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Warna.redup)),
            ],
          ),
        ),
      ],
    );
  }
}

class _BarisAntrian extends StatelessWidget {
  const _BarisAntrian({required this.entry});

  final OutboxEntry entry;

  @override
  Widget build(BuildContext context) {
    final outbox = context.read<Outbox>();
    final gagal = entry.isGagal;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(gagal ? Icons.error_outline : Icons.schedule, size: 20, color: gagal ? Warna.bahaya : Warna.peringatan),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.label, style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(
                  '${Fmt.jam(entry.createdAt)}${entry.lastError == null ? ' · menunggu sinyal' : ' · ${entry.lastError}'}',
                  style: TextStyle(fontSize: 12, color: gagal ? Warna.bahaya : Warna.redup),
                ),
                if (gagal)
                  Wrap(
                    spacing: 4,
                    children: [
                      if (entry.lastCode == 'possible_duplicate')
                        TextButton(
                          onPressed: () => outbox.retry(entry, tambahan: {'confirm_not_duplicate': true}),
                          child: const Text('Outlet berbeda, kirim'),
                        )
                      else if (entry.lastCode != 'dependency_failed')
                        TextButton(onPressed: () => outbox.retry(entry), child: const Text('Coba lagi')),
                      TextButton(
                        onPressed: () async {
                          final ya = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Hapus dari antrian?'),
                              content: Text('"${entry.label}" tidak akan dikirim ke Enesis.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Batal')),
                                FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Hapus')),
                              ],
                            ),
                          );
                          if (ya == true) await outbox.discard(entry);
                        },
                        child: const Text('Hapus', style: TextStyle(color: Warna.bahaya)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
