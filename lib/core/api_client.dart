import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'config.dart';

/// Error dari server Enesis: `{"error": {"code", "message", "fields"}}`.
/// [status] 0 = tidak sampai ke server (tanpa sinyal, timeout).
class ApiException implements Exception {
  ApiException(this.status, this.code, this.message, [this.fields = const {}]);

  final int status;
  final String code;
  final String message;
  final Map<String, dynamic> fields;

  /// Tidak sampai ke server atau gangguan server: simpan di antrian dan coba lagi nanti.
  bool get bolehDiulang => status == 0 || status == 429 || status >= 500;

  /// Harus login ulang (token dicabut, HP lain, akun nonaktif).
  bool get perluLogin => status == 401;

  /// Pesan pertama untuk sebuah field (validasi 422).
  String? pesanField(String nama) {
    final v = fields[nama];
    if (v is List && v.isNotEmpty) return v.first.toString();
    if (v is String) return v;
    return null;
  }

  @override
  String toString() => 'ApiException($status, $code): $message';
}

/// Respons sukses: `{"data": ..., "meta": {...}}`.
class ApiResponse {
  ApiResponse(this.status, this.data, this.meta);

  final int status;
  final dynamic data;
  final Map<String, dynamic> meta;

  bool get duplikat => meta['duplicate'] == true;
}

/// Pembungkus HTTP ke /api/mobile/v1: token Bearer, X-App-Version, Idempotency-Key, dan
/// konversi error ke [ApiException].
class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        baseUrl = baseUrl ?? AppConfig.apiBaseUrl;

  final http.Client _client;
  final String baseUrl;
  String? token;

  /// Dipanggil saat server menjawab 401 (mis. device_replaced) supaya aplikasi kembali ke login.
  void Function(ApiException e)? onUnauthorized;

  Uri uri(String path, [Map<String, dynamic>? query]) {
    final q = query?.map((k, v) => MapEntry(k, v.toString()));
    return Uri.parse('$baseUrl/${path.replaceFirst(RegExp(r'^/'), '')}').replace(queryParameters: q?.isEmpty ?? true ? null : q);
  }

  Map<String, String> _headers({String? idempotencyKey, bool json = true}) => {
        'Accept': 'application/json',
        if (json) 'Content-Type': 'application/json',
        'X-App-Version': AppConfig.appVersion,
        if (token != null) 'Authorization': 'Bearer $token',
        if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey,
      };

  Future<ApiResponse> get(String path, {Map<String, dynamic>? query}) =>
      _kirim(() => _client.get(uri(path, query), headers: _headers(json: false)));

  Future<ApiResponse> post(String path, {Object? body, String? idempotencyKey}) => _kirim(() => _client.post(
        uri(path),
        headers: _headers(idempotencyKey: idempotencyKey),
        body: jsonEncode(body ?? const {}),
      ));

  /// Unggah file (multipart) ke /uploads.
  Future<ApiResponse> upload(String path, {required String filePath, required Map<String, String> fields}) =>
      _kirim(() async {
        final req = http.MultipartRequest('POST', uri(path))
          ..headers.addAll(_headers(json: false))
          ..fields.addAll(fields)
          ..files.add(await http.MultipartFile.fromPath('file', filePath));
        return http.Response.fromStream(await _client.send(req));
      });

  Future<ApiResponse> _kirim(Future<http.Response> Function() panggil) async {
    http.Response res;
    try {
      res = await panggil().timeout(AppConfig.requestTimeout);
    } on TimeoutException {
      throw ApiException(0, 'timeout', 'Server tidak menjawab. Data disimpan dan dikirim ulang otomatis.');
    } on SocketException {
      throw ApiException(0, 'offline', 'Tidak ada sinyal. Data disimpan dan dikirim saat online.');
    } on http.ClientException {
      throw ApiException(0, 'offline', 'Tidak ada sinyal. Data disimpan dan dikirim saat online.');
    }

    return parse(res.statusCode, res.body, onUnauthorized);
  }

  /// Ubah status + isi respons menjadi [ApiResponse] atau lempar [ApiException].
  static ApiResponse parse(int status, String body, [void Function(ApiException e)? onUnauthorized]) {
    dynamic isi;
    try {
      isi = body.isEmpty ? null : jsonDecode(body);
    } on FormatException {
      isi = null;
    }

    if (status >= 200 && status < 300) {
      final map = isi is Map<String, dynamic> ? isi : <String, dynamic>{};
      final meta = map['meta'];
      return ApiResponse(status, map['data'], meta is Map<String, dynamic> ? meta : <String, dynamic>{});
    }

    final err = isi is Map && isi['error'] is Map ? isi['error'] as Map : const {};
    final fields = err['fields'];
    final e = ApiException(
      status,
      (err['code'] ?? (status >= 500 ? 'server_error' : 'http_$status')).toString(),
      (err['message'] ?? (status >= 500 ? 'Gangguan di server. Data akan dikirim ulang.' : 'Permintaan ditolak server.')).toString(),
      fields is Map<String, dynamic> ? fields : const {},
    );

    if (status == 401) onUnauthorized?.call(e);
    throw e;
  }
}
