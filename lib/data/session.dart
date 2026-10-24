import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../core/api_client.dart';
import '../core/config.dart';
import '../core/local_db.dart';

/// Login per HP: token Bearer disimpan di penyimpanan aman (Keystore). Satu akun hanya aktif di
/// satu HP; bila server menjawab 401 (mis. device_replaced) sesi dihapus dan kembali ke login.
class Session extends ChangeNotifier {
  Session(this.api, this.local, {FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage() {
    api.onUnauthorized = (e) => _paksaKeluar(e.message);
  }

  final ApiClient api;
  final LocalDb local;
  final FlutterSecureStorage _storage;

  Map<String, dynamic>? profil;
  bool siap = false;

  /// Pesan untuk layar login setelah sesi dicabut server.
  String? pesanKeluar;

  bool get masuk => api.token != null && profil != null;
  bool get wajibGantiPassword => profil?['must_change_password'] == true;
  String get nama => (profil?['name'] ?? '').toString();
  String get namaDepan => nama.split(' ').first;
  Map<String, dynamic>? get depo => profil?['depot'] as Map<String, dynamic>?;
  Map<String, dynamic>? get koordinator => profil?['coordinator'] as Map<String, dynamic>?;

  Future<void> init() async {
    api.token = await _storage.read(key: 'token');
    profil = await local.read('profil') as Map<String, dynamic>?;

    if (api.token != null) {
      try {
        profil = (await api.get('me')).data as Map<String, dynamic>;
        await local.write('profil', profil);
      } on ApiException catch (e) {
        // Tanpa sinyal: tetap masuk memakai profil tersimpan.
        if (e.perluLogin) profil = null;
      }
    }

    siap = true;
    notifyListeners();
  }

  /// ID instalasi aplikasi (tetap selama aplikasi tidak dihapus).
  Future<String> deviceId() async {
    var id = await _storage.read(key: 'device_id');
    if (id == null) {
      id = const Uuid().v4();
      await _storage.write(key: 'device_id', value: id);
    }
    return id;
  }

  Future<void> login(String username, String password) async {
    final res = await api.post('auth/login', body: {
      'username': username.trim(),
      'password': password,
      'device_id': await deviceId(),
      'device_model': _modelHp(),
      'app_version': AppConfig.appVersion,
    });
    final data = res.data as Map<String, dynamic>;

    // Akun lain di HP yang sama: buang data lokal akun sebelumnya.
    final lama = await local.read('profil') as Map<String, dynamic>?;
    final baru = data['user'] as Map<String, dynamic>;
    if (lama != null && lama['id'] != baru['id']) await local.clearAll();

    api.token = data['token'] as String;
    await _storage.write(key: 'token', value: api.token);
    profil = baru;
    await local.write('profil', profil);
    pesanKeluar = null;
    notifyListeners();
  }

  Future<void> gantiPassword({String? passwordLama, required String passwordBaru}) async {
    await api.post('auth/change-password', body: {
      if (passwordLama != null && passwordLama.isNotEmpty) 'current_password': passwordLama,
      'password': passwordBaru,
      'password_confirmation': passwordBaru,
    });
    profil = {...?profil, 'must_change_password': false};
    await local.write('profil', profil);
    notifyListeners();
  }

  /// Logout: cabut token di server (bila online) lalu hapus data lokal.
  Future<void> logout() async {
    try {
      await api.post('auth/logout');
    } on ApiException {
      // Tetap keluar walau tanpa sinyal; token di server dicabut saat login berikutnya.
    }
    await _hapusSesi();
    await local.clearAll();
    notifyListeners();
  }

  Future<void> _paksaKeluar(String pesan) async {
    if (api.token == null) return;
    pesanKeluar = pesan;
    await _hapusSesi();
    notifyListeners();
  }

  static String _modelHp() {
    final s = '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
    return s.length > 100 ? s.substring(0, 100) : s;
  }

  Future<void> _hapusSesi() async {
    api.token = null;
    profil = null;
    await _storage.delete(key: 'token');
    await local.remove('profil');
  }
}
