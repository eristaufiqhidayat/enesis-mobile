import 'dart:convert';

import 'package:enesis_mobile/core/api_client.dart';
import 'package:enesis_mobile/core/outbox.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Server palsu: mencatat permintaan dan menjawab sesuai [jawab].
class ServerPalsu {
  final permintaan = <http.Request>[];
  http.Response Function(http.Request r) jawab = (_) => http.Response('{"data":{}}', 201);
  bool offline = false;

  late final client = MockClient((r) async {
    if (offline) throw http.ClientException('offline');
    permintaan.add(r);
    return jawab(r);
  });

  List<String> get paths => permintaan.map((r) => r.url.path.replaceFirst('/api/mobile/v1/', '')).toList();
}

OutboxEntry post(String path, {Map<String, dynamic>? body, String? ref, String? idField, String key = '11111111-1111-4111-8111-111111111111'}) =>
    OutboxEntry(kind: OutboxEntry.kindPost, path: path, key: key, label: path, body: body, ref: ref, idField: idField);

void main() {
  late ServerPalsu server;
  late Outbox outbox;
  var jam = DateTime(2026, 10, 26, 9);

  setUp(() {
    server = ServerPalsu();
    jam = DateTime(2026, 10, 26, 9);
    final api = ApiClient(client: server.client, baseUrl: 'https://enesis.test/api/mobile/v1')..token = 'enm_x';
    outbox = Outbox(MemoryOutboxStore(), api, clock: () => jam);
  });

  test('online: langsung terkirim dengan Idempotency-Key, client_ref, dan token', () async {
    final r = await outbox.submit(post('attendances/check-in', body: {'lat': -6.2}));

    expect(r.queued, isFalse);
    expect(outbox.isEmpty, isTrue);
    final req = server.permintaan.single;
    expect(req.headers['Idempotency-Key'], '11111111-1111-4111-8111-111111111111');
    expect(req.headers['Authorization'], 'Bearer enm_x');
    expect(req.headers['X-App-Version'], isNotEmpty);
    final body = jsonDecode(req.body) as Map;
    expect(body['client_ref'], '11111111-1111-4111-8111-111111111111');
    expect(body['recorded_at'], isNotNull);
    expect(body['lat'], -6.2);
  });

  test('offline: masuk antrian lalu terkirim berurutan dengan rujukan @ref', () async {
    server.offline = true;
    await outbox.submit(post('visits', ref: 'visit-a', idField: 'visit_id', key: 'aaaaaaaa-0000-4000-8000-000000000001'));
    await outbox.submit(post('visits/@ref:visit-a/stocks', body: {'items': []}, key: 'aaaaaaaa-0000-4000-8000-000000000002'));
    await outbox.submit(post('sales', body: {'visit_id': '@ref:visit-a'}, key: 'aaaaaaaa-0000-4000-8000-000000000003'));
    expect(outbox.pendingCount, 3);

    server.offline = false;
    server.jawab = (r) => r.url.path.endsWith('/visits')
        ? http.Response('{"data":{"visit_id":552901}}', 201)
        : http.Response('{"data":{}}', 201);
    await outbox.flush(force: true);

    expect(outbox.isEmpty, isTrue);
    expect(server.paths, ['visits', 'visits/552901/stocks', 'sales']);
    expect(jsonDecode(server.permintaan.last.body)['visit_id'], 552901, reason: '@ref penuh menjadi angka');
  });

  test('gangguan server: berhenti dan coba lagi setelah jeda', () async {
    server.jawab = (_) => http.Response('{"error":{"code":"server_error","message":"x"}}', 503);
    final r = await outbox.submit(post('attendances/check-in'));

    expect(r.queued, isTrue);
    expect(outbox.entries.single.attempts, 1);
    expect(outbox.entries.single.nextTryAt, jam.add(const Duration(seconds: 10)));

    // Belum waktunya: tidak dikirim.
    final sebelum = server.permintaan.length;
    await outbox.flush();
    expect(server.permintaan.length, sebelum);

    server.jawab = (_) => http.Response('{"data":{"attendance_id":1}}', 201);
    jam = jam.add(const Duration(seconds: 11));
    await outbox.flush();
    expect(outbox.isEmpty, isTrue);
  });

  test('online ditolak 422: dilempar ke layar, tidak masuk antrian', () async {
    server.jawab = (_) => http.Response(
        '{"error":{"code":"outside_depot_radius","message":"Anda 240 m dari depo, batas 100 m.","fields":{"distance_m":240}}}', 422);

    await expectLater(
      outbox.submit(post('attendances/check-in')),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'outside_depot_radius').having((e) => e.fields['distance_m'], 'distance', 240)),
    );
    expect(outbox.isEmpty, isTrue);
  });

  test('antrian ditolak: ditandai gagal, transaksi turunannya tertahan, lainnya tetap jalan', () async {
    server.offline = true;
    await outbox.submit(post('outlets', ref: 'noo-a', idField: 'new_outlet_id', key: 'bbbbbbbb-0000-4000-8000-000000000001'));
    await outbox.submit(post('visits', body: {'new_outlet_id': '@ref:noo-a'}, key: 'bbbbbbbb-0000-4000-8000-000000000002'));
    await outbox.submit(post('tracking-lain', key: 'bbbbbbbb-0000-4000-8000-000000000003'));

    server.offline = false;
    server.jawab = (r) => r.url.path.endsWith('/outlets')
        ? http.Response('{"error":{"code":"possible_duplicate","message":"Sudah ada outlet dalam radius 20 m."}}', 422)
        : http.Response('{"data":{"new_outlet_id":7}}', 201);
    await outbox.flush(force: true);

    expect(outbox.entries.map((e) => (e.path, e.status, e.lastCode)).toList(), [
      ('outlets', OutboxEntry.gagal, 'possible_duplicate'),
      ('visits', OutboxEntry.gagal, 'dependency_failed'),
    ]);
    expect(server.paths, ['outlets', 'tracking-lain']);

    // Diperbaiki (outlet memang berbeda): kirim ulang dengan penanda; turunannya ikut terkirim.
    server.jawab = (r) => http.Response('{"data":{"new_outlet_id":7,"visit_id":9}}', 201);
    await outbox.retry(outbox.entries.first, tambahan: {'confirm_not_duplicate': true});

    expect(outbox.isEmpty, isTrue);
    expect(jsonDecode(server.permintaan[server.permintaan.length - 2].body)['confirm_not_duplicate'], true);
    expect(jsonDecode(server.permintaan.last.body)['new_outlet_id'], 7);
  });

  test('401 menghentikan antrian tanpa menandai gagal', () async {
    var keluar = false;
    outbox.api.onUnauthorized = (_) => keluar = true;
    server.offline = true;
    await outbox.submit(post('attendances/check-in'));

    server.offline = false;
    server.jawab = (_) => http.Response('{"error":{"code":"device_replaced","message":"Akun Anda masuk di HP lain."}}', 401);
    await outbox.flush(force: true);

    expect(keluar, isTrue);
    expect(outbox.entries.single.isGagal, isFalse);
  });

  test('jeda coba ulang bertahap', () {
    expect(Outbox.backoff(1), const Duration(seconds: 10));
    expect(Outbox.backoff(2), const Duration(seconds: 30));
    expect(Outbox.backoff(3), const Duration(minutes: 2));
    expect(Outbox.backoff(9), const Duration(minutes: 5));
  });

  test('refsDalam menemukan rujukan di path dan isi bertingkat', () {
    expect(Outbox.refsDalam('visits/@ref:visit-1/stocks'), {'visit-1'});
    expect(
      Outbox.refsDalam({
        'a': '@ref:foto-1',
        'b': [
          {'c': '@ref:foto-2'},
        ],
        'd': 3,
      }),
      {'foto-1', 'foto-2'},
    );
  });
}
