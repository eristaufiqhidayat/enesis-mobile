import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/api_client.dart';
import '../core/format.dart';
import '../core/geo.dart';
import '../core/local_db.dart';
import '../core/outbox.dart';
import 'lokasi.dart';

/// Data satu hari kerja motoris. Semua aksi dicatat dulu di HP (status lokal + antrian), jadi
/// layar langsung berubah walau tanpa sinyal; data server dipakai saat online.
class Hari extends ChangeNotifier {
  Hari(this.api, this.local, this.outbox) {
    outbox.onSent = (_, __) => _setelahTerkirim();
    outbox.addListener(notifyListeners);
  }

  final ApiClient api;
  final LocalDb local;
  final Outbox outbox;
  static const _uuid = Uuid();

  Map<String, dynamic> config = {};
  Map<String, dynamic> master = {};
  Map<String, dynamic>? ringkasan;
  Map<String, dynamic>? canvassing;
  List<Map<String, dynamic>> rute = [];
  Map<String, dynamic> ruteMeta = {};
  Map<String, dynamic> lokal = {};
  bool memuat = false;
  String? galatMuat;

  /// Menu sales sedang dipakai (Shell). Akun koordinator memakai [Koordinator], bukan kelas ini.
  bool aktif = false;

  String get tanggal => Fmt.ymd(DateTime.now());
  String get _kunciHari => 'hari:$tanggal';

  // ---------- muat ----------

  /// Baca cache dulu (tampil instan), lalu perbarui dari server bila online.
  Future<void> muat({bool server = true}) async {
    aktif = true;
    config = Map<String, dynamic>.from(await local.read('config') ?? {});
    master = Map<String, dynamic>.from(await local.read('master') ?? {});
    ringkasan = await local.read('ringkasan:$tanggal') as Map<String, dynamic>?;
    canvassing = await local.read('canvassing:$tanggal') as Map<String, dynamic>?;
    rute = List<Map<String, dynamic>>.from(await local.read('rute:$tanggal') ?? []);
    ruteMeta = Map<String, dynamic>.from(await local.read('rute_meta:$tanggal') ?? {});
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

      final masterLama = await local.readTime('master');
      if (masterLama == null || DateTime.now().difference(masterLama).inHours >= 12 || master.isEmpty) {
        master = Map<String, dynamic>.from((await api.get('master')).data as Map);
        await local.write('master', master);
      }

      // Data hari ini dari server hanya dipakai bila antrian kosong, supaya status lokal yang
      // belum terkirim tidak tertimpa.
      if (outbox.pendingCount == 0) {
        ringkasan = Map<String, dynamic>.from((await api.get('me/summary')).data as Map);
        await local.write('ringkasan:$tanggal', ringkasan);

        final c = (await api.get('canvassing/today')).data;
        canvassing = c == null ? null : Map<String, dynamic>.from(c as Map);
        await local.write('canvassing:$tanggal', canvassing);

        await _muatRute();
      }
    } on ApiException catch (e) {
      galatMuat = e.bolehDiulang ? 'Offline · data terakhir tersimpan' : e.message;
    } finally {
      memuat = false;
      notifyListeners();
    }
  }

  Future<void> _muatRute() async {
    final semua = <Map<String, dynamic>>[];
    int? cursor;
    Map<String, dynamic> meta = {};

    do {
      final res = await api.get('routes/today', query: {if (cursor != null) 'cursor': cursor});
      semua.addAll((res.data as List).map((e) => Map<String, dynamic>.from(e as Map)));
      meta = res.meta;
      cursor = meta['next_cursor'] as int?;
    } while (cursor != null && semua.length < 2000);

    rute = semua;
    ruteMeta = meta;
    await local.write('rute:$tanggal', rute);
    await local.write('rute_meta:$tanggal', ruteMeta);
  }

  Future<void> _setelahTerkirim() async {
    if (!aktif) return;
    if (outbox.pendingCount == 0) {
      try {
        ringkasan = Map<String, dynamic>.from((await api.get('me/summary')).data as Map);
        await local.write('ringkasan:$tanggal', ringkasan);
      } on ApiException {
        // dicoba lagi saat segarkan berikutnya
      }
    }
    notifyListeners();
  }

  Future<void> _simpanLokal() async {
    await local.write(_kunciHari, lokal);
    notifyListeners();
  }

  // ---------- turunan untuk layar ----------

  Map<String, dynamic> get depo => Map<String, dynamic>.from(config['depot'] as Map? ?? {});
  int get minimalTransaksi => (config['min_transaction_value'] as num?)?.toInt() ?? 35000;
  Map<String, dynamic> get target => Map<String, dynamic>.from(config['daily_targets'] as Map? ?? {});

  /// Area kerja aktif sales (acuan absen, bukan checkin depo). Dari Master Area;
  /// server yang mengirim polygon jadi, HP hanya memeriksa titik di dalam/luarnya.
  List<Map<String, dynamic>> get areaKerja =>
      List<Map<String, dynamic>>.from((config['work_areas'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)));

  /// true bila [t] berada di dalam salah satu area kerja aktif. Sales tanpa area
  /// kerja (areaKerja kosong) selalu false — tidak ada jalan pintas ke radius depo.
  bool dalamAreaKerja(Titik t) => titikDalamSalahSatuArea(t.lat, t.lng, areaKerja);

  List<Map<String, dynamic>> get produk =>
      List<Map<String, dynamic>>.from((master['products'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)));

  Map<int, Map<String, dynamic>> get produkById => {for (final p in produk) (p['id'] as num).toInt(): p};

  List<String> get tipeOutlet => List<String>.from(master['outlet_types'] as List? ?? const ['Toko', 'Warung']);

  List<Map<String, dynamic>> get alasanTidakBeli =>
      List<Map<String, dynamic>>.from((master['no_sale_reasons'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)));

  List<Map<String, dynamic>> get kompetitor =>
      List<Map<String, dynamic>>.from((master['competitor_products'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)));

  bool _serverSelesai(String key) =>
      (ringkasan?['steps'] as List? ?? []).any((s) => s is Map && s['key'] == key && s['done'] == true);

  bool get sudahAbsen => lokal['absen_at'] != null || _serverSelesai('attendance');
  bool get sudahCheckinDepo => lokal['depo_at'] != null || _serverSelesai('depot_check_in');
  bool get sudahTerimaBarang => lokal['terima_at'] != null || _serverSelesai('accept_goods') || canvassing?['accepted_at'] != null;
  bool get sudahKembali => lokal['kembali_at'] != null || canvassing?['returned_at'] != null;
  bool get sudahTutup => lokal['tutup_at'] != null || _serverSelesai('close_day');

  List<Map<String, dynamic>> get kunjungan =>
      List<Map<String, dynamic>>.from((lokal['kunjungan'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)));

  Map<String, dynamic>? get kunjunganTerbuka {
    final ref = lokal['buka'];
    if (ref == null) return null;
    for (final k in kunjungan) {
      if (k['ref'] == ref) return k;
    }
    return null;
  }

  /// Langkah Beranda: (label, selesai, keterangan).
  List<(String, bool, String)> get langkah {
    final c = canvassing;
    final items = (c?['items'] as List? ?? []);
    final kunjunganServer = (ringkasan?['kpi']?['call']?['value'] as num?)?.toInt() ?? 0;
    return [
      ('Absen masuk', sudahAbsen, Fmt.jam(Fmt.parse(lokal['absen_at']) ?? _waktuLangkah('attendance'))),
      ('Checkin depo', sudahCheckinDepo, Fmt.jam(Fmt.parse(lokal['depo_at']) ?? _waktuLangkah('depot_check_in'))),
      ('Terima barang canvassing', sudahTerimaBarang, items.isEmpty ? '' : '${items.length} SKU'),
      ('Kunjungi outlet', sudahKembali, '${kunjungan.length > kunjunganServer ? kunjungan.length : kunjunganServer} / ${ruteMeta['total'] ?? rute.length}'),
      ('Kembalikan sisa & checkout', sudahTutup, ''),
    ];
  }

  DateTime? _waktuLangkah(String key) {
    for (final s in (ringkasan?['steps'] as List? ?? [])) {
      if (s is Map && s['key'] == key) return Fmt.parse(s['at']);
    }
    return null;
  }

  /// KPI hari ini: nilai terbesar antara hitungan server dan catatan lokal (yang mungkin belum terkirim).
  Map<String, num> get kpi {
    final jual = kunjungan.where((k) => k['status'] == 'beli').toList();
    final lokalKpi = <String, num>{
      'call': kunjungan.length,
      'ec': jual.where((k) => k['ec'] == true).length,
      'omset': jual.fold<num>(0, (a, k) => a + ((k['total'] as num?) ?? 0)),
      'ipt': jual.isEmpty ? 0 : jual.fold<num>(0, (a, k) => a + ((k['sku'] as num?) ?? 0)) / jual.length,
    };
    final s = ringkasan?['kpi'] as Map? ?? {};
    num ambil(String k, String kunciServer) {
      final v = (s[kunciServer] is Map ? (s[kunciServer] as Map)['value'] : null) as num? ?? 0;
      return v > lokalKpi[k]! ? v : lokalKpi[k]!;
    }

    return {
      'call': ambil('call', 'call'),
      'ec': ambil('ec', 'ec'),
      'ipt': ambil('ipt', 'ipt'),
      'omset': ambil('omset', 'sales_amount'),
      'poin': (s['points'] as num?) ?? 0,
    };
  }

  /// Status kunjungan per outlet (server digabung catatan lokal).
  String statusOutlet(Map<String, dynamic> o) {
    final id = o['id'];
    for (final k in kunjungan.reversed) {
      if (k['outlet_id'] == id) return k['status'] as String;
    }
    return (o['visit_status'] ?? 'belum') as String;
  }

  Map<String, dynamic>? get outletBerikutnya {
    final n = ringkasan?['next_outlet'];
    if (n is Map && kunjungan.every((k) => k['outlet_id'] != n['id'])) return Map<String, dynamic>.from(n);
    for (final o in rute) {
      if (statusOutlet(o) == 'belum') return o;
    }
    return null;
  }

  /// Barang bawaan dengan sisa yang sudah dikurangi order lokal.
  List<Map<String, dynamic>> get bawaan =>
      List<Map<String, dynamic>>.from((canvassing?['items'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)));

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

    // Terunggah langsung: salinan di folder antrian tidak diperlukan lagi.
    if (!r.queued) await LocalDb.hapusFoto(simpan);
    return '@ref:$ref';
  }

  /// Langkah 1 — Absen masuk: selfie + lokasi di dalam area kerja aktif (bukan
  /// radius depo). Terpisah dari checkin depo karena area kerja sales bisa jauh
  /// dari depo; checkin depo baru dicek saat sales sampai di gudang.
  Future<bool> absenMasuk(String fotoPath, Titik t) async {
    final foto = await unggahFoto(fotoPath, 'selfie', 'Foto selfie absen');
    final r = await outbox.submit(_post('attendances/check-in', 'Absen masuk', {...t.toJson(), 'photo_id': foto}));
    lokal['absen_at'] = DateTime.now().toIso8601String();
    await _simpanLokal();
    return r.queued;
  }

  /// Langkah 2 — Checkin depo: lokasi di dalam radius depo (tidak berubah),
  /// dilakukan saat sales tiba di gudang untuk ambil barang canvassing.
  Future<bool> checkinDepo(Titik t) async {
    final r = await outbox.submit(_post('depot-visits/check-in', 'Checkin depo', t.toJson()));
    lokal['depo_at'] = DateTime.now().toIso8601String();
    await _simpanLokal();
    return r.queued;
  }

  /// Terima barang canvassing. [diterima] = product_id -> (qty, alasan) untuk yang berselisih.
  Future<bool> terimaBarang(Map<int, (num, String)> diterima) async {
    final c = canvassing!;
    final r = await outbox.submit(_post('canvassing/${c['number']}/accept', 'Terima barang ${c['number']}', {
      'items': [
        for (final e in diterima.entries) {'product_id': e.key, 'qty_received': e.value.$1, 'reason': e.value.$2},
      ],
    }));

    if (r.response?.data is Map) {
      canvassing = Map<String, dynamic>.from(r.response!.data as Map);
    } else {
      canvassing = {
        ...c,
        'status': 'diterima',
        'items': [
          for (final i in bawaan)
            {
              ...i,
              'qty_carried': diterima[i['product_id']]?.$1 ?? i['qty_prepared'],
              'qty_remaining': diterima[i['product_id']]?.$1 ?? i['qty_prepared'],
            },
        ],
      };
    }

    await local.write('canvassing:$tanggal', canvassing);
    lokal['terima_at'] = DateTime.now().toIso8601String();
    await _simpanLokal();
    return r.queued;
  }

  /// Checkin outlet (master [outletId] atau NOO dengan [outletBaruRef]).
  Future<Map<String, dynamic>> checkinOutlet({
    int? outletId,
    String? outletBaruRef,
    required String nama,
    String? kode,
    String? alamat,
    required Titik t,
    String? fotoPath,
  }) async {
    final ref = 'visit-${_uuid.v4()}';
    final foto = fotoPath == null ? null : await unggahFoto(fotoPath, 'toko', 'Foto toko $nama');
    final r = await outbox.submit(_post(
      'visits',
      'Checkin $nama',
      {
        ...t.toJson(),
        if (outletId != null) 'outlet_id': outletId,
        if (outletBaruRef != null) 'new_outlet_id': outletBaruRef,
        if (foto != null) 'photo_id': foto,
      },
      ref: ref,
      idField: 'visit_id',
    ));

    final data = r.response?.data as Map? ?? {};
    final k = <String, dynamic>{
      'ref': ref,
      'outlet_id': outletId,
      'nama': nama,
      'kode': kode,
      'alamat': alamat,
      'checkin_at': DateTime.now().toIso8601String(),
      'jarak_m': data['distance_to_outlet_m'],
      'luar_rute': data['is_off_route'] ?? false,
      'status': 'dikunjungi',
    };
    lokal['kunjungan'] = [...kunjungan, k];
    lokal['buka'] = ref;
    await _simpanLokal();
    return k;
  }

  Future<void> simpanStok(Map<String, dynamic> k, Map<int, num> stok, Map<String, num> stokKompetitor) async {
    await outbox.submit(_post('visits/@ref:${k['ref']}/stocks', 'Stok ${k['nama']}', {
      'items': [for (final e in stok.entries) {'product_id': e.key, 'qty': e.value}],
      'competitors': [for (final e in stokKompetitor.entries) {'name': e.key, 'qty': e.value}],
    }));
    _ubahKunjungan(k['ref'] as String, {'stok_dicatat': true});
    await _simpanLokal();
  }

  /// Tidak beli lalu checkout outlet.
  Future<void> tidakBeli(Map<String, dynamic> k, String kode, String? catatan) async {
    await outbox.submit(_post('visits/@ref:${k['ref']}/no-sale', 'Tidak beli ${k['nama']}', {
      'reason_code': kode,
      if (catatan != null && catatan.isNotEmpty) 'note': catatan,
    }));
    await _checkout(k, {'status': 'tidak_beli', 'alasan': kode});
  }

  /// Simpan order lalu checkout outlet. [qty] = product_id -> qty.
  Future<void> buatOrder(Map<String, dynamic> k, Map<int, num> qty) async {
    final items = qty.entries.where((e) => e.value > 0).toList();
    final harga = {for (final b in bawaan) (b['product_id'] as num).toInt(): (b['price'] as num?) ?? 0};
    final total = items.fold<num>(0, (a, e) => a + e.value * (harga[e.key] ?? 0));

    await outbox.submit(_post('sales', 'Order ${k['nama']}', {
      'visit_id': '@ref:${k['ref']}',
      'client_total': total.round(),
      'items': [for (final e in items) {'product_id': e.key, 'qty': e.value}],
    }));

    // Kurangi sisa bawaan di HP.
    canvassing = {
      ...?canvassing,
      'items': [
        for (final b in bawaan)
          {
            ...b,
            'qty_sold': ((b['qty_sold'] as num?) ?? 0) + (qty[(b['product_id'] as num).toInt()] ?? 0),
            'qty_remaining': ((b['qty_remaining'] as num?) ?? 0) - (qty[(b['product_id'] as num).toInt()] ?? 0),
          },
      ],
    };
    await local.write('canvassing:$tanggal', canvassing);

    await _checkout(k, {'status': 'beli', 'total': total, 'sku': items.length, 'ec': total >= minimalTransaksi});
  }

  Future<void> _checkout(Map<String, dynamic> k, Map<String, dynamic> ubah) async {
    await outbox.submit(_post('visits/@ref:${k['ref']}/check-out', 'Checkout ${k['nama']}', {}));
    _ubahKunjungan(k['ref'] as String, {...ubah, 'checkout_at': DateTime.now().toIso8601String()});
    lokal['buka'] = null;
    await _simpanLokal();
  }

  void _ubahKunjungan(String ref, Map<String, dynamic> ubah) {
    lokal['kunjungan'] = [
      for (final k in kunjungan) k['ref'] == ref ? {...k, ...ubah} : k,
    ];
  }

  /// Outlet baru (NOO). [fotoToko]/[fotoRak] = rujukan dari [unggahFoto], supaya kirim ulang
  /// (mis. setelah `possible_duplicate`) tidak mengunggah foto lagi. Bila online dan server mendeteksi
  /// kemungkinan duplikat, [ApiException] `possible_duplicate` dilempar (fields.candidates); kirim
  /// ulang dengan [bukanDuplikat] = true.
  Future<String> daftarOutletBaru({
    required String nama,
    String? pemilik,
    String? hp,
    String? tipe,
    String? alamat,
    required Titik t,
    required String fotoToko,
    String? fotoRak,
    bool bukanDuplikat = false,
  }) async {
    final ref = 'noo-${_uuid.v4()}';

    await outbox.submit(_post(
      'outlets',
      'Outlet baru $nama',
      {
        ...t.toJson(),
        'name': nama,
        if (pemilik != null && pemilik.isNotEmpty) 'owner_name': pemilik,
        if (hp != null && hp.isNotEmpty) 'phone': hp,
        if (tipe != null) 'type': tipe,
        if (alamat != null && alamat.isNotEmpty) 'address': alamat,
        'photo_store_id': fotoToko,
        if (fotoRak != null) 'photo_shelf_id': fotoRak,
        if (bukanDuplikat) 'confirm_not_duplicate': true,
      },
      ref: ref,
      idField: 'new_outlet_id',
    ));
    return '@ref:$ref';
  }

  /// Tutup hari: serahkan sisa barang, checkout depo, absen pulang.
  /// [kembali] = product_id -> (qty, alasan) untuk yang tidak sama dengan sisa.
  Future<bool> tutupHari(Map<int, (num, String)> kembali, Titik? t) async {
    var antri = false;
    final c = canvassing;

    if (c != null && !sudahKembali) {
      antri |= (await outbox.submit(_post('canvassing/${c['number']}/return', 'Serahkan sisa ${c['number']}', {
        'items': [
          for (final e in kembali.entries) {'product_id': e.key, 'qty_returned': e.value.$1, 'reason': e.value.$2},
        ],
      })))
          .queued;
      lokal['kembali_at'] = DateTime.now().toIso8601String();
      await _simpanLokal();
    }

    antri |= (await outbox.submit(_post('depot-visits/check-out', 'Checkout depo', t?.toJson() ?? {}))).queued;
    antri |= (await outbox.submit(_post('attendances/check-out', 'Absen pulang', t?.toJson() ?? {}))).queued;
    lokal['tutup_at'] = DateTime.now().toIso8601String();
    await _simpanLokal();
    return antri;
  }

  /// Total penjualan hari ini (tunai yang disetor).
  num get totalPenjualan => kpi['omset'] ?? 0;
}
