import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/api_client.dart';
import '../core/format.dart';
import '../core/geo.dart';
import '../core/local_db.dart';
import '../core/outbox.dart';
import 'lokasi.dart';

/// Data satu hari kerja koordinator: absen, tim (sales bawahan) hari ini, dan join visit.
/// Sama seperti [Hari] milik sales: aksi dicatat dulu di HP (status lokal + antrian), jadi
/// layar langsung berubah walau tanpa sinyal; data server dipakai saat online.
class Koordinator extends ChangeNotifier {
  Koordinator(this.api, this.local, this.outbox) {
    outbox.addListener(notifyListeners);
  }

  final ApiClient api;
  final LocalDb local;
  final Outbox outbox;
  static const _uuid = Uuid();

  Map<String, dynamic> config = {};
  List<Map<String, dynamic>> tim = [];
  Map<String, dynamic> timMeta = {};
  List<Map<String, dynamic>> joinVisitServer = [];
  Map<String, dynamic>? absenServer;
  Map<String, dynamic> lokal = {};
  bool memuat = false;
  String? galatMuat;

  String get tanggal => Fmt.ymd(DateTime.now());
  String get _kunciHari => 'koor:$tanggal';

  // ---------- muat ----------

  Future<void> muat({bool server = true}) async {
    config = Map<String, dynamic>.from(await local.read('config') ?? {});
    tim = _daftar(await local.read('tim:$tanggal'));
    timMeta = Map<String, dynamic>.from(await local.read('tim_meta:$tanggal') ?? {});
    joinVisitServer = _daftar(await local.read('jv:$tanggal'));
    absenServer = await local.read('absen:$tanggal') as Map<String, dynamic>?;
    lokal = Map<String, dynamic>.from(await local.read(_kunciHari) ?? {});
    await outbox.load();
    notifyListeners();

    if (server) await segarkan();
  }

  Future<void> segarkan() async {
    memuat = true;
    galatMuat = null;
    notifyListeners();

    try {
      await outbox.flush();

      config = Map<String, dynamic>.from((await api.get('config')).data as Map);
      await local.write('config', config);

      final absen = (await api.get('attendances')).data as List? ?? [];
      absenServer = null;
      for (final a in absen) {
        if (a is Map && a['date'] == tanggal) absenServer = Map<String, dynamic>.from(a);
      }
      await local.write('absen:$tanggal', absenServer);

      final res = await api.get('team/today');
      tim = _daftar(res.data);
      timMeta = res.meta;
      await local.write('tim:$tanggal', tim);
      await local.write('tim_meta:$tanggal', timMeta);

      // Riwayat dari server hanya dipakai bila antrian kosong, supaya join visit lokal yang
      // belum terkirim tidak hilang dari layar.
      if (outbox.pendingCount == 0) {
        joinVisitServer = _daftar((await api.get('join-visits')).data);
        await local.write('jv:$tanggal', joinVisitServer);
        lokal['join_visit'] = <dynamic>[];
        if (joinVisitServer.every((j) => j['status'] == 'selesai')) lokal['buka'] = null;
        await _simpanLokal();
      }
    } on ApiException catch (e) {
      galatMuat = e.bolehDiulang ? 'Offline · data terakhir tersimpan' : e.message;
    } finally {
      memuat = false;
    }
    notifyListeners();
  }

  static List<Map<String, dynamic>> _daftar(dynamic v) =>
      List<Map<String, dynamic>>.from((v as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)));

  Future<void> _simpanLokal() async {
    await local.write(_kunciHari, lokal);
    notifyListeners();
  }

  // ---------- turunan untuk layar ----------

  Map<String, dynamic> get depo => Map<String, dynamic>.from(config['depot'] as Map? ?? {});
  int get radiusOutlet => (config['outlet_radius_m'] as num?)?.toInt() ?? 100;

  /// Area kerja untuk absen koordinator = gabungan area aktif seluruh sales di
  /// timnya (server yang menghitung union-nya, sama field `work_areas` dengan
  /// sales). Tim tanpa area aktif → daftar kosong → absen selalu ditolak.
  List<Map<String, dynamic>> get areaKerja =>
      List<Map<String, dynamic>>.from((config['work_areas'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)));

  bool dalamAreaKerja(Titik t) => titikDalamSalahSatuArea(t.lat, t.lng, areaKerja);

  bool get sudahAbsen => lokal['absen_at'] != null || absenServer != null;
  bool get sudahPulang => lokal['pulang_at'] != null || absenServer?['checked_out_at'] != null;
  DateTime? get jamMasuk => Fmt.parse(lokal['absen_at']) ?? Fmt.parse(absenServer?['checked_in_at']);
  DateTime? get jamPulang => Fmt.parse(lokal['pulang_at']) ?? Fmt.parse(absenServer?['checked_out_at']);
  bool get terlambat => absenServer?['is_late'] == true;

  /// Join visit lokal (belum ada / belum dimuat ulang dari server).
  List<Map<String, dynamic>> get _joinVisitLokal => _daftar(lokal['join_visit']);

  /// Join visit hari ini: catatan lokal dulu (terbaru), lalu data server.
  List<Map<String, dynamic>> get joinVisit => [..._joinVisitLokal.reversed, ...joinVisitServer];

  /// Join visit yang sedang berjalan (lokal atau dari server).
  Map<String, dynamic>? get joinVisitBerjalan {
    final ref = lokal['buka'];
    if (ref != null) {
      for (final j in _joinVisitLokal) {
        if (j['ref'] == ref) return j;
      }
    }
    for (final j in joinVisitServer) {
      if (j['status'] == 'berlangsung') return j;
    }
    return null;
  }

  int get jumlahJoinVisitSelesai => joinVisit.where((j) => j['status'] == 'selesai').length;

  // ---------- aksi ----------

  OutboxEntry _post(String path, String label, Map<String, dynamic> body, {String? ref, String? idField}) => OutboxEntry(
        kind: OutboxEntry.kindPost,
        path: path,
        key: _uuid.v4(),
        label: label,
        body: body,
        ref: ref,
        idField: idField,
      );

  /// Unggah foto lewat antrian; hasilnya rujukan `@ref:foto-…` untuk dipakai di transaksi.
  Future<String> unggahFoto(String path, String jenis, String label) async {
    final ref = 'foto-${_uuid.v4()}';
    final simpan = await LocalDb.simpanFoto(path, ref);
    final r = await outbox.submit(OutboxEntry(
      kind: OutboxEntry.kindUpload,
      path: 'uploads',
      key: _uuid.v4(),
      label: label,
      filePath: simpan,
      uploadType: jenis,
      ref: ref,
      idField: 'upload_id',
    ));

    if (!r.queued) await LocalDb.hapusFoto(simpan);
    return '@ref:$ref';
  }

  /// Absen masuk dengan selfie.
  Future<bool> absenMasuk(String fotoPath, Titik t) async {
    final foto = await unggahFoto(fotoPath, 'selfie', 'Foto selfie absen');
    final r = await outbox.submit(_post('attendances/check-in', 'Absen masuk', {...t.toJson(), 'photo_id': foto}));
    lokal['absen_at'] = DateTime.now().toIso8601String();
    await _simpanLokal();
    return r.queued;
  }

  /// Absen pulang (join visit harus sudah selesai).
  Future<bool> absenPulang(Titik? t) async {
    final r = await outbox.submit(_post('attendances/check-out', 'Absen pulang', t?.toJson() ?? {}));
    lokal['pulang_at'] = DateTime.now().toIso8601String();
    await _simpanLokal();
    return r.queued;
  }

  /// Outlet master terdekat (butuh sinyal).
  Future<List<Map<String, dynamic>>> outletTerdekat(Titik t, {String? cari, int radius = 300}) async {
    final res = await api.get('coordinator/outlets/nearby', query: {
      'lat': t.lat,
      'lng': t.lng,
      'radius': radius,
      if (cari != null && cari.trim().isNotEmpty) 'q': cari.trim(),
    });
    return _daftar(res.data);
  }

  /// Mulai join visit bersama [sales] di [outlet].
  Future<bool> mulaiJoinVisit(Map<String, dynamic> sales, Map<String, dynamic> outlet, Titik t) async {
    final ref = 'jv-${_uuid.v4()}';
    final r = await outbox.submit(_post(
      'join-visits',
      'Join visit ${outlet['name']}',
      {...t.toJson(), 'sales_id': sales['id'], 'outlet_id': outlet['id']},
      ref: ref,
      idField: 'join_visit_id',
    ));

    final data = r.response?.data as Map? ?? {};
    lokal['join_visit'] = [
      ..._joinVisitLokal,
      {
        'ref': ref,
        'id': data['join_visit_id'],
        'date': tanggal,
        'sales': {'id': sales['id'], 'name': sales['name']},
        'outlet': {'id': outlet['id'], 'code': outlet['code'], 'name': outlet['name'], 'address': outlet['address']},
        'started_at': DateTime.now().toIso8601String(),
        'distance_to_outlet_m': data['distance_to_outlet_m'] ?? outlet['distance_m'],
        'status': 'berlangsung',
      },
    ];
    lokal['buka'] = ref;
    await _simpanLokal();
    return r.queued;
  }

  /// Selesaikan join visit yang berjalan dengan catatan + foto.
  Future<bool> selesaiJoinVisit(Map<String, dynamic> jv, String catatan, String fotoPath, Titik? t) async {
    final foto = await unggahFoto(fotoPath, 'lampiran', 'Foto join visit ${jv['outlet']?['name'] ?? ''}');
    // Join visit dari server sudah punya id; yang dicatat di HP memakai rujukan antrian.
    final idPath = jv['ref'] != null ? '@ref:${jv['ref']}' : '${jv['id']}';
    final r = await outbox.submit(_post('join-visits/$idPath/finish', 'Selesai join visit ${jv['outlet']?['name'] ?? ''}', {
      ...?t?.toJson(),
      'note': catatan.trim(),
      'photo_id': foto,
    }));

    final selesai = {...jv, 'status': 'selesai', 'finished_at': DateTime.now().toIso8601String(), 'note': catatan.trim()};
    if (jv['ref'] != null) {
      lokal['join_visit'] = [for (final j in _joinVisitLokal) j['ref'] == jv['ref'] ? selesai : j];
    } else {
      joinVisitServer = [for (final j in joinVisitServer) j['id'] == jv['id'] ? selesai : j];
      await local.write('jv:$tanggal', joinVisitServer);
    }
    lokal['buka'] = null;
    await _simpanLokal();
    return r.queued;
  }
}
