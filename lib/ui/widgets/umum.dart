import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_client.dart';
import '../../data/lokasi.dart';
import '../theme.dart';

/// Kartu putih membulat (section di mockup).
class Kartu extends StatelessWidget {
  const Kartu({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.warna});

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? warna;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: warna ?? Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Label kecil abu-abu + nilai (mis. "Jam server · 07:41 WIB").
class BarisInfo extends StatelessWidget {
  const BarisInfo(this.label, this.nilai, {super.key, this.tebal = false});

  final String label;
  final String nilai;
  final bool tebal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: Warna.redup))),
          Text(nilai, style: TextStyle(fontSize: 14, fontWeight: tebal ? FontWeight.w600 : FontWeight.w500)),
        ],
      ),
    );
  }
}

/// Kotak catatan berwarna (info / peringatan / sukses).
class Catatan extends StatelessWidget {
  const Catatan(this.teks, {super.key, this.jenis = JenisCatatan.info, this.ikon});

  final String teks;
  final JenisCatatan jenis;
  final IconData? ikon;

  @override
  Widget build(BuildContext context) {
    final (latar, depan, i) = switch (jenis) {
      JenisCatatan.info => (Warna.biruMuda, Warna.biruTua, Icons.info_outline),
      JenisCatatan.sukses => (Warna.suksesMuda, Warna.sukses, Icons.check_circle_outline),
      JenisCatatan.peringatan => (Warna.peringatanMuda, Warna.peringatan, Icons.warning_amber_rounded),
      JenisCatatan.bahaya => (Warna.bahayaMuda, Warna.bahaya, Icons.error_outline),
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: latar, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ikon ?? i, size: 18, color: depan),
          const SizedBox(width: 8),
          Expanded(child: Text(teks, style: TextStyle(fontSize: 13, color: depan, height: 1.35))),
        ],
      ),
    );
  }
}

enum JenisCatatan { info, sukses, peringatan, bahaya }

/// Chip kecil (status kunjungan, tag depo).
class Lencana extends StatelessWidget {
  const Lencana(this.teks, {super.key, this.latar = Warna.biruMuda, this.depan = Warna.biruTua});

  final String teks;
  final Color latar;
  final Color depan;

  static Lencana status(String status) => switch (status) {
        'beli' => const Lencana('Beli', latar: Warna.suksesMuda, depan: Warna.sukses),
        'tidak_beli' => const Lencana('Tidak beli', latar: Warna.peringatanMuda, depan: Warna.peringatan),
        'dikunjungi' => const Lencana('Dikunjungi', latar: Warna.biruMuda, depan: Warna.biruTua),
        _ => const Lencana('Belum', latar: Warna.jalur, depan: Warna.redup),
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: latar, borderRadius: BorderRadius.circular(12)),
      child: Text(teks, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: depan)),
    );
  }
}

/// Tombol − qty + (stok & order).
class StepperQty extends StatelessWidget {
  const StepperQty({super.key, required this.nilai, required this.onUbah, this.maks});

  final num nilai;
  final ValueChanged<num> onUbah;
  final num? maks;

  @override
  Widget build(BuildContext context) {
    Widget tombol(IconData ikon, VoidCallback? aksi) => SizedBox(
          width: 40,
          height: 40,
          child: IconButton.outlined(
            onPressed: aksi,
            icon: Icon(ikon, size: 18),
            style: IconButton.styleFrom(side: const BorderSide(color: Warna.garis)),
          ),
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        tombol(Icons.remove, nilai > 0 ? () => onUbah(nilai - 1) : null),
        SizedBox(
          width: 44,
          child: Text(
            nilai == nilai.roundToDouble() ? nilai.round().toString() : nilai.toString(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        tombol(Icons.add, maks == null || nilai < maks! ? () => onUbah(nilai + 1) : null),
      ],
    );
  }
}

/// Kotak ambil foto dari kamera (selfie / depan toko / rak).
class FotoKotak extends StatelessWidget {
  const FotoKotak({super.key, required this.label, required this.path, required this.onFoto, this.depan = false, this.tinggi = 140});

  final String label;
  final String? path;
  final ValueChanged<String> onFoto;
  final bool depan;
  final double tinggi;

  Future<void> _ambil(BuildContext context) async {
    final foto = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: depan ? CameraDevice.front : CameraDevice.rear,
      maxWidth: 1280,
      imageQuality: 70,
    );
    if (foto != null) onFoto(foto.path);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _ambil(context),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: tinggi,
        decoration: BoxDecoration(
          color: Warna.latar,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Warna.garis, width: 1.5),
          image: path == null ? null : DecorationImage(image: FileImage(File(path!)), fit: BoxFit.cover),
        ),
        child: path != null
            ? Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Lencana('✓ $label', latar: Warna.sukses, depan: Colors.white),
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.photo_camera_outlined, color: Warna.tautan, size: 28),
                  const SizedBox(height: 6),
                  Text(label, style: const TextStyle(color: Warna.tautan, fontWeight: FontWeight.w600)),
                ],
              ),
      ),
    );
  }
}

/// Bar progres KPI.
class BarProgres extends StatelessWidget {
  const BarProgres(this.rasio, {super.key, this.warna = Warna.aksen});

  final double rasio;
  final Color warna;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: LinearProgressIndicator(value: rasio.clamp(0, 1), minHeight: 6, backgroundColor: Warna.jalur, color: warna),
    );
  }
}

/// Tombol utama dengan status memproses.
class TombolUtama extends StatelessWidget {
  const TombolUtama(this.label, {super.key, required this.onPressed, this.proses = false, this.ikon});

  final String label;
  final Future<void> Function()? onPressed;
  final bool proses;
  final IconData? ikon;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: proses || onPressed == null ? null : () => onPressed!(),
      icon: proses
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Icon(ikon ?? Icons.check),
      label: Text(label),
    );
  }
}

/// Tampilkan pesan error dari server / GPS / lainnya.
void tampilkanGalat(BuildContext context, Object e) {
  final pesan = switch (e) {
    ApiException(:final message) => message,
    LokasiException(:final message) => message,
    _ => 'Terjadi kesalahan: $e',
  };
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(pesan), backgroundColor: Warna.bahaya));
}

void tampilkanInfo(BuildContext context, String pesan) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(pesan)));
}

/// Pesan setelah aksi: terkirim atau masuk antrian.
void tampilkanHasil(BuildContext context, bool antri, String terkirim) {
  tampilkanInfo(context, antri ? 'Tersimpan di HP. Dikirim otomatis saat online.' : terkirim);
}

/// Kotak sudut atas header biru dengan judul dan subjudul.
class HeaderBiru extends StatelessWidget {
  const HeaderBiru({super.key, required this.judul, this.subjudul, this.aksi});

  final String judul;
  final String? subjudul;
  final Widget? aksi;

  @override
  Widget build(BuildContext context) {
    final bisaKembali = Navigator.of(context).canPop();
    return Container(
      color: Warna.biruTua,
      padding: EdgeInsets.fromLTRB(bisaKembali ? 4 : 20, MediaQuery.of(context).padding.top + 12, 12, 16),
      child: Row(
        children: [
          if (bisaKembali) const BackButton(color: Colors.white),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(judul, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                if (subjudul != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subjudul!, style: const TextStyle(color: Warna.biruHeaderTeks, fontSize: 13)),
                  ),
              ],
            ),
          ),
          if (aksi != null) aksi!,
        ],
      ),
    );
  }
}
