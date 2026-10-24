import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../core/api_client.dart';
import '../core/local_db.dart';

/// Posisi GPS saat ini beserta penanda lokasi palsu (mock location Android).
class Titik {
  Titik(this.lat, this.lng, this.akurasi, this.palsu, this.waktu);

  final double lat;
  final double lng;
  final double akurasi;
  final bool palsu;
  final DateTime waktu;

  Map<String, dynamic> toJson() => {
        'lat': double.parse(lat.toStringAsFixed(7)),
        'lng': double.parse(lng.toStringAsFixed(7)),
        'accuracy_m': akurasi.round(),
        'is_mock_location': palsu,
      };

  /// Jarak (meter) ke titik lain.
  double jarakKe(double lat2, double lng2) => Geolocator.distanceBetween(lat, lng, lat2, lng2);
}

class LokasiException implements Exception {
  LokasiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class Lokasi {
  /// Minta izin bila perlu lalu ambil posisi akurat (maks. 20 detik).
  static Future<Titik> sekarang() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw LokasiException('GPS mati. Nyalakan lokasi di HP lalu coba lagi.');
    }

    var izin = await Geolocator.checkPermission();
    if (izin == LocationPermission.denied) izin = await Geolocator.requestPermission();
    if (izin == LocationPermission.denied || izin == LocationPermission.deniedForever) {
      throw LokasiException('Izin lokasi ditolak. Izinkan lokasi untuk Enesis di pengaturan HP.');
    }

    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)),
      );
      return Titik(p.latitude, p.longitude, p.accuracy, p.isMocked, DateTime.now());
    } on TimeoutException {
      throw LokasiException('Lokasi belum didapat. Coba di tempat terbuka.');
    } on PermissionDeniedException {
      throw LokasiException('Izin lokasi ditolak. Izinkan lokasi untuk Enesis di pengaturan HP.');
    } on LocationServiceDisabledException {
      throw LokasiException('GPS mati. Nyalakan lokasi di HP lalu coba lagi.');
    }
  }
}

/// Pencatat GPS selama jam kerja (aplikasi terbuka): satu titik per interval dari /config,
/// disimpan di HP lalu dikirim per paket ke /tracking/batch.
class Pelacak {
  Pelacak(this.local, this.api);

  final LocalDb local;
  final ApiClient api;
  Timer? _catat;
  Timer? _kirim;

  bool get aktif => _catat != null;

  void mulai({int intervalDetik = 180}) {
    if (aktif) return;
    _catat = Timer.periodic(Duration(seconds: intervalDetik.clamp(30, 3600)), (_) => _ambil());
    _kirim = Timer.periodic(const Duration(minutes: 5), (_) => kirim());
    _ambil();
  }

  void berhenti() {
    _catat?.cancel();
    _kirim?.cancel();
    _catat = null;
    _kirim = null;
    kirim();
  }

  Future<void> _ambil() async {
    try {
      final t = await Lokasi.sekarang();
      await local.addGps(t.waktu, t.lat, t.lng, t.akurasi, t.palsu);
    } catch (_) {
      // GPS mati / izin dicabut / gagal baca: lewati titik ini.
    }
  }

  /// Kirim titik tersimpan (maks. 500 per paket). Titik kembar diabaikan server.
  Future<void> kirim() async {
    while (true) {
      final rows = await local.gpsBatch(500);
      if (rows.isEmpty || api.token == null) return;

      try {
        await api.post('tracking/batch', body: {
          'points': [
            for (final r in rows)
              {
                'recorded_at': r['recorded_at'],
                'lat': r['lat'],
                'lng': r['lng'],
                'accuracy_m': r['accuracy_m'],
                'is_mock_location': r['is_mock'] == 1,
              },
          ],
        });
      } on ApiException catch (e) {
        if (e.bolehDiulang || e.perluLogin) return;
        // Ditolak (mis. validasi): buang paket supaya tidak macet.
      }

      await local.removeGps([for (final r in rows) r['recorded_at'] as String]);
      if (rows.length < 500) return;
    }
  }
}
