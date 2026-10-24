import 'package:enesis_mobile/core/api_client.dart';
import 'package:enesis_mobile/core/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Fmt', () {
    test('rupiah dan ribuan', () {
      expect(Fmt.rupiah(75500), 'Rp75.500');
      expect(Fmt.rupiah(1691000), 'Rp1.691.000');
      expect(Fmt.rupiah(0), 'Rp0');
      expect(Fmt.ribuan(-2500), '-2.500');
    });

    test('ringkas untuk KPI', () {
      expect(Fmt.ringkas(486000), '486 rb');
      expect(Fmt.ringkas(1690000), '1,69 jt');
      expect(Fmt.ringkas(750), '750');
    });

    test('desimal, qty, jarak', () {
      expect(Fmt.desimal(2.6), '2,6');
      expect(Fmt.desimal(3), '3');
      expect(Fmt.qty(4.0), '4');
      expect(Fmt.qty(2.5), '2,5');
      expect(Fmt.jarak(350), '350 m');
      expect(Fmt.jarak(1260), '1,3 km');
    });

    test('tanggal Indonesia', () {
      expect(Fmt.tanggal(DateTime(2026, 10, 23)), 'Jumat, 23 Okt 2026');
      expect(Fmt.bulanTahun(DateTime(2026, 10, 1)), 'Oktober 2026');
      expect(Fmt.jam(DateTime(2026, 10, 23, 7, 5)), '07:05');
      expect(Fmt.ymd(DateTime(2026, 1, 9)), '2026-01-09');
    });
  });

  group('ApiClient.parse', () {
    test('sukses mengembalikan data dan meta', () {
      final r = ApiClient.parse(200, '{"data":{"visit_id":1},"meta":{"duplicate":true}}');
      expect(r.data, {'visit_id': 1});
      expect(r.duplikat, isTrue);
    });

    test('error membawa code, pesan, dan fields', () {
      try {
        ApiClient.parse(422, '{"error":{"code":"validation_failed","message":"Foto selfie wajib.","fields":{"photo_id":["Foto selfie wajib."]}}}');
        fail('harus melempar');
      } on ApiException catch (e) {
        expect(e.code, 'validation_failed');
        expect(e.pesanField('photo_id'), 'Foto selfie wajib.');
        expect(e.bolehDiulang, isFalse);
      }
    });

    test('5xx tanpa isi JSON boleh diulang; 401 memanggil onUnauthorized', () {
      expect(() => ApiClient.parse(502, '<html>Bad gateway</html>'),
          throwsA(isA<ApiException>().having((e) => e.bolehDiulang, 'ulang', isTrue)));

      ApiException? keluar;
      expect(() => ApiClient.parse(401, '{"error":{"code":"device_replaced","message":"HP lain"}}', (e) => keluar = e),
          throwsA(isA<ApiException>()));
      expect(keluar?.code, 'device_replaced');
    });
  });
}
