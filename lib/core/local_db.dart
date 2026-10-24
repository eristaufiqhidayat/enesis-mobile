import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'outbox.dart';

/// Database lokal di HP: antrian transaksi, nilai rujukan (@ref), cache data (master, rute,
/// muatan canvassing, status hari ini), dan titik GPS yang belum terkirim.
class LocalDb {
  LocalDb._(this.db);

  final Database db;

  static Future<LocalDb> open() async {
    final db = await openDatabase(
      p.join(await getDatabasesPath(), 'enesis_mobile.db'),
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE outbox (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            kind TEXT NOT NULL, path TEXT NOT NULL, body TEXT NOT NULL, key TEXT NOT NULL,
            label TEXT NOT NULL, ref TEXT, id_field TEXT, file_path TEXT, upload_type TEXT,
            status TEXT NOT NULL, attempts INTEGER NOT NULL DEFAULT 0, last_code TEXT, last_error TEXT,
            created_at TEXT NOT NULL, next_try_at TEXT
          )''');
        await db.execute('CREATE TABLE refs (name TEXT PRIMARY KEY, value TEXT NOT NULL)');
        await db.execute('CREATE TABLE cache (key TEXT PRIMARY KEY, value TEXT NOT NULL, updated_at TEXT NOT NULL)');
        await db.execute('''
          CREATE TABLE gps (
            recorded_at TEXT PRIMARY KEY, lat REAL NOT NULL, lng REAL NOT NULL,
            accuracy_m REAL, is_mock INTEGER NOT NULL DEFAULT 0
          )''');
      },
    );
    return LocalDb._(db);
  }

  // ---- cache JSON ----

  Future<dynamic> read(String key) async {
    final rows = await db.query('cache', where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : jsonDecode(rows.first['value'] as String);
  }

  Future<DateTime?> readTime(String key) async {
    final rows = await db.query('cache', columns: ['updated_at'], where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : DateTime.tryParse(rows.first['updated_at'] as String);
  }

  Future<void> write(String key, dynamic value) => db.insert(
        'cache',
        {'key': key, 'value': jsonEncode(value), 'updated_at': DateTime.now().toIso8601String()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<void> remove(String key) => db.delete('cache', where: 'key = ?', whereArgs: [key]);

  /// Hapus semua data lokal (logout). Antrian ikut terhapus; aplikasi memperingatkan dulu.
  Future<void> clearAll() async {
    for (final t in ['outbox', 'refs', 'cache', 'gps']) {
      await db.delete(t);
    }
  }

  // ---- titik GPS ----

  Future<void> addGps(DateTime t, double lat, double lng, double? accuracy, bool mock) => db.insert(
        'gps',
        {'recorded_at': t.toUtc().toIso8601String(), 'lat': lat, 'lng': lng, 'accuracy_m': accuracy, 'is_mock': mock ? 1 : 0},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

  Future<List<Map<String, Object?>>> gpsBatch(int limit) => db.query('gps', orderBy: 'recorded_at', limit: limit);

  Future<void> removeGps(List<String> recordedAt) async {
    final batch = db.batch();
    for (final t in recordedAt) {
      batch.delete('gps', where: 'recorded_at = ?', whereArgs: [t]);
    }
    await batch.commit(noResult: true);
  }

  /// Salin foto dari folder sementara kamera ke folder aplikasi supaya tidak hilang sebelum terkirim.
  static Future<String> simpanFoto(String sumber, String nama) async {
    final dir = Directory(p.join((await getApplicationDocumentsDirectory()).path, 'antrian_foto'));
    await dir.create(recursive: true);
    final tujuan = p.join(dir.path, '$nama${p.extension(sumber).isEmpty ? '.jpg' : p.extension(sumber)}');
    await File(sumber).copy(tujuan);
    return tujuan;
  }
}

/// [OutboxStore] di atas sqflite.
class SqfliteOutboxStore implements OutboxStore {
  SqfliteOutboxStore(this.local);

  final LocalDb local;
  Database get _db => local.db;

  Map<String, Object?> _row(OutboxEntry e) => {
        'kind': e.kind,
        'path': e.path,
        'body': jsonEncode(e.body),
        'key': e.key,
        'label': e.label,
        'ref': e.ref,
        'id_field': e.idField,
        'file_path': e.filePath,
        'upload_type': e.uploadType,
        'status': e.status,
        'attempts': e.attempts,
        'last_code': e.lastCode,
        'last_error': e.lastError,
        'created_at': e.createdAt.toIso8601String(),
        'next_try_at': e.nextTryAt?.toIso8601String(),
      };

  OutboxEntry _entry(Map<String, Object?> r) => OutboxEntry(
        id: r['id'] as int,
        kind: r['kind'] as String,
        path: r['path'] as String,
        body: Map<String, dynamic>.from(jsonDecode(r['body'] as String) as Map),
        key: r['key'] as String,
        label: r['label'] as String,
        ref: r['ref'] as String?,
        idField: r['id_field'] as String?,
        filePath: r['file_path'] as String?,
        uploadType: r['upload_type'] as String?,
        status: r['status'] as String,
        attempts: r['attempts'] as int,
        lastCode: r['last_code'] as String?,
        lastError: r['last_error'] as String?,
        createdAt: DateTime.parse(r['created_at'] as String),
        nextTryAt: r['next_try_at'] == null ? null : DateTime.parse(r['next_try_at'] as String),
      );

  @override
  Future<int> add(OutboxEntry e) async => e.id = await _db.insert('outbox', _row(e));

  @override
  Future<List<OutboxEntry>> all() async => (await _db.query('outbox', orderBy: 'id')).map(_entry).toList();

  @override
  Future<void> update(OutboxEntry e) => _db.update('outbox', _row(e), where: 'id = ?', whereArgs: [e.id]);

  @override
  Future<void> remove(int id) async {
    final rows = await _db.query('outbox', columns: ['file_path'], where: 'id = ?', whereArgs: [id]);
    await _db.delete('outbox', where: 'id = ?', whereArgs: [id]);

    // Foto yang sudah terunggah tidak perlu disimpan lagi.
    final f = rows.isEmpty ? null : rows.first['file_path'] as String?;
    if (f != null && f.contains('antrian_foto')) {
      try {
        await File(f).delete();
      } on FileSystemException {
        // sudah terhapus
      }
    }
  }

  @override
  Future<String?> refValue(String name) async {
    final rows = await _db.query('refs', where: 'name = ?', whereArgs: [name], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  @override
  Future<void> setRef(String name, String value) =>
      _db.insert('refs', {'name': name, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
}
