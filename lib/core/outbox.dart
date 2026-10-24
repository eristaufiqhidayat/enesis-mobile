import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// Satu transaksi di antrian HP. Transaksi dicatat dulu di HP lalu dikirim berurutan; dihapus
/// setelah server menjawab sukses atau duplikat.
///
/// Rujukan ke hasil transaksi lain ditulis `@ref:<nama>` di [path] atau [body], mis.
/// `visits/@ref:visit-1a2b/stocks` atau `{"photo_id": "@ref:foto-9c8d"}`. Nilainya diisi dari
/// `data[idField]` respons transaksi yang punya [ref] tersebut.
class OutboxEntry {
  OutboxEntry({
    this.id,
    required this.kind,
    required this.path,
    required this.key,
    required this.label,
    Map<String, dynamic>? body,
    this.ref,
    this.idField,
    this.filePath,
    this.uploadType,
    this.status = OutboxEntry.menunggu,
    this.attempts = 0,
    this.lastCode,
    this.lastError,
    DateTime? createdAt,
    this.nextTryAt,
  })  : body = body ?? <String, dynamic>{},
        createdAt = createdAt ?? DateTime.now();

  static const menunggu = 'menunggu';
  static const gagal = 'gagal';
  static const kindPost = 'post';
  static const kindUpload = 'upload';

  int? id;
  final String kind;
  final String path;
  final Map<String, dynamic> body;

  /// UUID: dikirim sebagai Idempotency-Key dan client_ref.
  final String key;
  final String label;
  final String? ref;
  final String? idField;
  final String? filePath;
  final String? uploadType;
  String status;
  int attempts;
  String? lastCode;
  String? lastError;
  final DateTime createdAt;
  DateTime? nextTryAt;

  bool get isGagal => status == gagal;
}

/// Penyimpanan antrian (sqflite di aplikasi, memori di tes).
abstract class OutboxStore {
  Future<int> add(OutboxEntry e);
  Future<List<OutboxEntry>> all();
  Future<void> update(OutboxEntry e);
  Future<void> remove(int id);
  Future<String?> refValue(String name);
  Future<void> setRef(String name, String value);
}

class MemoryOutboxStore implements OutboxStore {
  final _entries = <int, OutboxEntry>{};
  final _refs = <String, String>{};
  var _seq = 0;

  @override
  Future<int> add(OutboxEntry e) async {
    e.id = ++_seq;
    _entries[e.id!] = e;
    return e.id!;
  }

  @override
  Future<List<OutboxEntry>> all() async => (_entries.values.toList()..sort((a, b) => a.id!.compareTo(b.id!)));

  @override
  Future<void> update(OutboxEntry e) async => _entries[e.id!] = e;

  @override
  Future<void> remove(int id) async => _entries.remove(id);

  @override
  Future<String?> refValue(String name) async => _refs[name];

  @override
  Future<void> setRef(String name, String value) async => _refs[name] = value;
}

/// Hasil [Outbox.submit]: terkirim (ada respons) atau masuk antrian (dikirim nanti).
class SubmitResult {
  SubmitResult.sent(ApiResponse this.response) : queued = false;
  SubmitResult.queued() : response = null, queued = true;

  final ApiResponse? response;
  final bool queued;
}

/// Pengirim antrian. Urutan dijaga (absen → depo → terima barang → kunjungan → order → kembali),
/// karena server menolak transaksi yang induknya belum diterima.
class Outbox extends ChangeNotifier {
  Outbox(this.store, this.api, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final OutboxStore store;
  final ApiClient api;
  final DateTime Function() _clock;

  /// Dipanggil setelah transaksi dari antrian diterima server.
  void Function(OutboxEntry entry, ApiResponse response)? onSent;

  /// Dipanggil saat transaksi dari antrian ditolak server (409/422) dan perlu diperbaiki.
  void Function(OutboxEntry entry, ApiException error)? onRejected;

  List<OutboxEntry> _cache = [];
  Future<void>? _berjalan;
  int _kirimLangsung = 0;
  DateTime? lastSyncAt;
  Timer? _timer;

  List<OutboxEntry> get entries => List.unmodifiable(_cache);
  int get pendingCount => _cache.where((e) => !e.isGagal).length;
  int get failedCount => _cache.where((e) => e.isGagal).length;
  bool get isEmpty => _cache.isEmpty;

  /// Jeda coba ulang: 10 dtk, 30 dtk, 2 mnt, lalu tiap 5 mnt.
  static Duration backoff(int attempts) => switch (attempts) {
        <= 1 => const Duration(seconds: 10),
        2 => const Duration(seconds: 30),
        3 => const Duration(minutes: 2),
        _ => const Duration(minutes: 5),
      };

  Future<void> load() async {
    _cache = await store.all();
    notifyListeners();
  }

  /// Coba kirim berkala selagi aplikasi terbuka.
  void start({Duration every = const Duration(seconds: 30)}) {
    _timer?.cancel();
    _timer = Timer.periodic(every, (_) => flush());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Kirim sekarang bila antrian kosong; bila tidak ada sinyal, simpan di antrian.
  /// Penolakan server (409/422) dilempar sebagai [ApiException] supaya layar bisa menampilkannya.
  Future<SubmitResult> submit(OutboxEntry entry) async {
    await load();

    if (_cache.where((e) => !e.isGagal).isEmpty && !await _punyaRefBelumAda(entry)) {
      _kirimLangsung++;
      try {
        final res = await _send(entry);
        lastSyncAt = _clock();
        notifyListeners();
        return SubmitResult.sent(res);
      } on ApiException catch (e) {
        if (!e.bolehDiulang) rethrow;
        entry.attempts = 1;
        entry.lastCode = e.code;
        entry.lastError = e.message;
        entry.nextTryAt = _clock().add(backoff(1));
      } finally {
        _kirimLangsung--;
      }
    }

    await store.add(entry);
    await load();
    unawaited(flush());
    return SubmitResult.queued();
  }

  /// Kirim antrian berurutan. Berhenti saat tidak ada sinyal / server gangguan / perlu login.
  Future<void> flush({bool force = false}) async {
    // Satu pengiriman pada satu waktu; panggilan berikutnya menunggu lalu jalan setelahnya.
    while (_berjalan != null) {
      await _berjalan;
    }
    final selesai = Completer<void>();
    _berjalan = selesai.future;

    try {
      await load();

      for (final e in List.of(_cache)) {
        if (e.isGagal) continue;
        if (!force && e.nextTryAt != null && e.nextTryAt!.isAfter(_clock())) break;

        final tunggu = await _statusRef(e);
        if (tunggu == _Ref.menunggu) break;
        if (tunggu == _Ref.gagal) {
          await _tandaiGagal(e, ApiException(0, 'dependency_failed', 'Transaksi sebelumnya ditolak server; perbaiki itu dulu.'));
          continue;
        }

        try {
          final res = await _send(e);
          await store.remove(e.id!);
          _cache.removeWhere((x) => x.id == e.id);
          lastSyncAt = _clock();
          onSent?.call(e, res);
        } on ApiException catch (err) {
          // Perlu login ulang / aplikasi harus diperbarui: hentikan tanpa menandai gagal.
          if (err.perluLogin || err.status == 426) break;

          if (err.bolehDiulang) {
            e.attempts++;
            e.lastCode = err.code;
            e.lastError = err.message;
            e.nextTryAt = _clock().add(backoff(e.attempts));
            await store.update(e);
            break;
          }

          await _tandaiGagal(e, err);
          onRejected?.call(e, err);
        }
      }
    } finally {
      await load();
      _berjalan = null;
      selesai.complete();
    }
  }

  /// Kirim ulang transaksi yang gagal (setelah diperbaiki di server / kondisi berubah).
  /// [tambahan] menambah field ke isi transaksi, mis. `{'confirm_not_duplicate': true}`.
  Future<void> retry(OutboxEntry e, {Map<String, dynamic> tambahan = const {}}) async {
    e.body.addAll(tambahan);
    e.status = OutboxEntry.menunggu;
    e.nextTryAt = null;
    e.lastError = null;
    e.lastCode = null;
    await store.update(e);

    // Transaksi yang tertahan karena transaksi ini ikut dicoba lagi.
    for (final x in _cache.where((x) => x.isGagal && x.lastCode == 'dependency_failed')) {
      x.status = OutboxEntry.menunggu;
      x.lastCode = null;
      x.lastError = null;
      await store.update(x);
    }

    await flush(force: true);
  }

  Future<void> discard(OutboxEntry e) async {
    await store.remove(e.id!);
    await load();
  }

  Future<ApiResponse> _send(OutboxEntry e) async {
    final path = await _isiRef(e.path) as String;
    final ApiResponse res;

    if (e.kind == OutboxEntry.kindUpload) {
      res = await api.upload(path, filePath: e.filePath!, fields: {'type': e.uploadType ?? 'lampiran'});
    } else {
      final body = Map<String, dynamic>.from(await _isiRef(e.body) as Map);
      body.putIfAbsent('client_ref', () => e.key);
      body.putIfAbsent('recorded_at', () => e.createdAt.toUtc().toIso8601String());
      res = await api.post(path, body: body, idempotencyKey: e.key);
    }

    if (e.ref != null && e.idField != null && res.data is Map && (res.data as Map)[e.idField] != null) {
      await store.setRef(e.ref!, (res.data as Map)[e.idField].toString());
    }

    return res;
  }

  Future<void> _tandaiGagal(OutboxEntry e, ApiException err) async {
    e.status = OutboxEntry.gagal;
    e.lastCode = err.code;
    e.lastError = err.message;
    await store.update(e);
  }

  static final _pola = RegExp(r'@ref:([A-Za-z0-9_\-]+)');

  static Set<String> refsDalam(dynamic nilai) {
    if (nilai is String) return _pola.allMatches(nilai).map((m) => m.group(1)!).toSet();
    if (nilai is Map) return nilai.values.expand(refsDalam).toSet();
    if (nilai is List) return nilai.expand(refsDalam).toSet();
    return {};
  }

  Future<bool> _punyaRefBelumAda(OutboxEntry e) async {
    for (final r in {...refsDalam(e.path), ...refsDalam(e.body)}) {
      if (await store.refValue(r) == null) return true;
    }
    return false;
  }

  Future<_Ref> _statusRef(OutboxEntry e) async {
    for (final r in {...refsDalam(e.path), ...refsDalam(e.body)}) {
      if (await store.refValue(r) != null) continue;
      final induk = _cache.where((x) => x.ref == r);
      // Induk mungkin sedang dikirim langsung oleh submit() lain.
      if (induk.isEmpty && _kirimLangsung > 0) return _Ref.menunggu;
      if (induk.isEmpty || induk.any((x) => x.isGagal)) return _Ref.gagal;
      return _Ref.menunggu;
    }
    return _Ref.siap;
  }

  /// Ganti `@ref:nama` dengan nilainya. Nilai yang seluruhnya `@ref:x` diganti angka bila numerik.
  Future<dynamic> _isiRef(dynamic nilai) async {
    if (nilai is String) {
      final semua = RegExp(r'^@ref:([A-Za-z0-9_\-]+)$').firstMatch(nilai);
      if (semua != null) {
        final v = await store.refValue(semua.group(1)!);
        return int.tryParse(v ?? '') ?? v;
      }
      var hasil = nilai;
      for (final r in refsDalam(nilai)) {
        hasil = hasil.replaceAll('@ref:$r', await store.refValue(r) ?? '');
      }
      return hasil;
    }
    if (nilai is Map) {
      return {for (final k in nilai.keys) k: await _isiRef(nilai[k])};
    }
    if (nilai is List) {
      return [for (final v in nilai) await _isiRef(v)];
    }
    return nilai;
  }
}

enum _Ref { siap, menunggu, gagal }
