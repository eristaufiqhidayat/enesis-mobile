/// Format tampilan Indonesia tanpa bergantung pada data locale intl.
class Fmt {
  static const _hari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
  static const _bulan = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
  static const _bulanPanjang = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  /// 75500 -> "Rp75.500"
  static String rupiah(num? nilai) => 'Rp${ribuan(nilai ?? 0)}';

  /// 1234567 -> "1.234.567"
  static String ribuan(num nilai) {
    final negatif = nilai < 0;
    final s = nilai.abs().round().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
      b.write(s[i]);
    }
    return '${negatif ? '-' : ''}$b';
  }

  /// Ringkas untuk kartu KPI: 486000 -> "486 rb", 1690000 -> "1,69 jt".
  static String ringkas(num nilai) {
    if (nilai.abs() >= 1000000) return '${desimal(nilai / 1000000, 2)} jt';
    if (nilai.abs() >= 1000) return '${(nilai / 1000).round()} rb';
    return nilai.round().toString();
  }

  /// 2.6 -> "2,6"; bilangan bulat tanpa koma.
  static String desimal(num nilai, [int digit = 1]) {
    if (nilai == nilai.roundToDouble()) return nilai.round().toString();
    var s = nilai.toStringAsFixed(digit);
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    return s.replaceAll('.', ',');
  }

  /// "Jumat, 23 Okt 2026"
  static String tanggal(DateTime t) => '${_hari[t.weekday - 1]}, ${t.day} ${_bulan[t.month - 1]} ${t.year}';

  /// "Oktober 2026"
  static String bulanTahun(DateTime t) => '${_bulanPanjang[t.month - 1]} ${t.year}';

  /// "07:41"
  static String jam(DateTime? t) => t == null ? '-' : '${_dua(t.hour)}:${_dua(t.minute)}';

  /// "2026-10-23" (tanggal lokal HP).
  static String ymd(DateTime t) => '${t.year}-${_dua(t.month)}-${_dua(t.day)}';

  static DateTime? parse(dynamic s) => s is String && s.isNotEmpty ? DateTime.tryParse(s)?.toLocal() : null;

  /// Jarak: 350 -> "350 m", 1250 -> "1,3 km"
  static String jarak(num? meter) {
    if (meter == null) return '-';
    return meter >= 1000 ? '${desimal(meter / 1000, 1)} km' : '${meter.round()} m';
  }

  /// Qty: 4.0 -> "4", 2.5 -> "2,5"
  static String qty(num? n) => desimal(n ?? 0, 2);

  static String _dua(int n) => n.toString().padLeft(2, '0');
}
