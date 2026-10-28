/// Util geometri sederhana untuk memeriksa apakah sebuah titik GPS berada di
/// dalam polygon Master Area (lihat `config['work_areas']`). Dipakai untuk
/// absen sales (area aktifnya sendiri) dan absen koordinator (gabungan area
/// aktif tim) — server yang menghitung gabungan/union area, HP hanya
/// menerima daftar polygon jadi di `work_areas` dan memeriksa titik ada di
/// salah satunya atau tidak.
library;

/// Titik dalam polygon (ray casting / even-odd rule). `polygon` = list titik
/// `{'lat': .., 'lng': ..}` membentuk satu cincin; titik awal tidak perlu
/// diulang di akhir. Polygon dengan < 3 titik dianggap tidak valid (false).
bool titikDalamPoligon(double lat, double lng, List<dynamic> polygon) {
  if (polygon.length < 3) return false;
  var dalam = false;
  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final pi = polygon[i] as Map;
    final pj = polygon[j] as Map;
    final latI = (pi['lat'] as num).toDouble();
    final lngI = (pi['lng'] as num).toDouble();
    final latJ = (pj['lat'] as num).toDouble();
    final lngJ = (pj['lng'] as num).toDouble();

    final potong = (lngI > lng) != (lngJ > lng) && lat < (latJ - latI) * (lng - lngI) / (lngJ - lngI) + latI;
    if (potong) dalam = !dalam;
  }
  return dalam;
}

/// true bila titik ada di dalam salah satu area pada [areas] (tiap elemen
/// punya field `polygon`). Area tanpa polygon valid dilewati begitu saja.
bool titikDalamSalahSatuArea(double lat, double lng, List<Map<String, dynamic>> areas) {
  for (final a in areas) {
    final poly = a['polygon'] as List?;
    if (poly != null && titikDalamPoligon(lat, lng, poly)) return true;
  }
  return false;
}

/// Area (dari [areas]) tempat titik berada, atau null bila di luar semuanya.
/// Dipakai untuk pesan "Anda di luar area kerja" dengan nama area terdekat/acuan.
Map<String, dynamic>? areaTempatTitik(double lat, double lng, List<Map<String, dynamic>> areas) {
  for (final a in areas) {
    final poly = a['polygon'] as List?;
    if (poly != null && titikDalamPoligon(lat, lng, poly)) return a;
  }
  return null;
}
