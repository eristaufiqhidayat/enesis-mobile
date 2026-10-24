# Enesis Motoris (Flutter)

Aplikasi Android untuk **sales motoris** (canvassing) Enesis, sesuai mockup "Enesis Mobile — Motoris & Canvassing".
Backend: API `/api/mobile/v1` di repo [`enesis`](https://github.com/eristaufiqhidayat/enesis) (kontrak:
`docs/api/mobile-v1.yaml`).

## Alur satu hari

| Layar | Isi |
|---|---|
| Login | Username + password akun Enesis. Menerbitkan 1 token untuk HP ini; login di HP lain mengeluarkan HP ini. Password awal wajib diganti. |
| Beranda | 5 langkah hari ini, Call / EC / IPT / Omset vs target, poin, tombol aksi berikutnya. |
| Absen & checkin depo | Selfie + GPS dalam radius depo, satu tombol. |
| Terima barang | Muatan canvassing dari staf depo; selisih wajib beralasan. |
| Rute | Outlet di area sales dengan status Belum / Beli / Tidak beli, cari, outlet baru. |
| Kunjungan | Checkin (jarak ke titik outlet), stok sendiri & kompetitor, Tidak beli atau Buat order. |
| Order | Produk dari sisa bawaan, produk fokus, cek minimal transaksi (EC), total. |
| Outlet baru (NOO) | Foto toko & rak, data pemilik, tipe, GPS; cek kemungkinan duplikat; langsung checkin. |
| Tutup hari | Bawa = terjual + kembali per SKU, uang tunai untuk disetor, checkout depo & absen pulang. |
| Kinerja | Rekap bulan ini dan perkiraan insentif. |
| Akun | Antrian kirim (transaksi belum terkirim / ditolak), ganti password, keluar. |

## Offline

Semua transaksi dicatat dulu di HP (sqflite) lalu dikirim berurutan (`lib/core/outbox.dart`):

- Setiap transaksi punya UUID yang dikirim sebagai `Idempotency-Key` dan `client_ref`, jadi aman dikirim ulang.
- Transaksi yang bergantung pada hasil transaksi lain memakai rujukan `@ref:<nama>`, mis. order ke kunjungan
  yang belum terkirim (`visits/@ref:visit-…/stocks`, `"visit_id": "@ref:visit-…"`), foto (`@ref:foto-…`).
- Tanpa sinyal / server gangguan: coba lagi 10 dtk, 30 dtk, 2 mnt, lalu tiap 5 mnt, dan saat aplikasi dibuka.
- Ditolak server (409/422): ditandai di **Akun › Antrian kirim** dengan pesan server; transaksi turunannya tertahan.
  Bisa "Coba lagi", "Outlet berbeda, kirim" (untuk kemungkinan duplikat), atau "Hapus".
- Saat online, penolakan langsung tampil di layar (mis. "Anda 240 m dari depo, batas 100 m").
- GPS dicatat tiap `gps_interval_s` (dari `/config`) antara absen masuk dan tutup hari, selama aplikasi terbuka,
  lalu dikirim per paket ke `/tracking/batch`.

## Menjalankan

Butuh Flutter 3.22+ (Dart 3.4+) dan Android SDK.

```bash
# sekali: buat folder platform Android (AndroidManifest.xml dengan izin lokasi/kamera sudah ada di repo
# dan tidak ditimpa)
flutter create --platforms=android --org com.marketama --project-name enesis_mobile .

flutter pub get
flutter analyze
flutter test

# jalankan ke HP (USB debugging) — server bawaan https://enesis.lembaharafah.com/api/mobile/v1
flutter run --dart-define=API_BASE_URL=https://enesis.lembaharafah.com/api/mobile/v1

# APK rilis
flutter build apk --release --dart-define=API_BASE_URL=https://enesis.lembaharafah.com/api/mobile/v1
```

Server lokal (`php artisan serve --host 0.0.0.0`) lewat HTTP perlu `android:usesCleartextTraffic="true"` di
`<application>` khusus untuk uji; jangan dipakai di rilis.

Untuk uji alur di server: muatan canvassing dibuat dengan
`php artisan enesis:siapkan-canvassing <karyawan_id> --produk=<produk_id>:<qty>` (form web staf depo belum ada).

## Struktur

```
lib/
  core/   api_client.dart (HTTP + ApiException), outbox.dart (antrian offline), local_db.dart (sqflite),
          format.dart (Rupiah/tanggal Indonesia), config.dart (--dart-define)
  data/   session.dart (login/token per HP), hari.dart (status hari kerja + aksi), lokasi.dart (GPS, pelacak)
  ui/     theme.dart (warna mockup), widgets/umum.dart, screens/*
test/     outbox_test.dart, format_api_test.dart, widget_test.dart
```

## Belum ada (tahap berikutnya)

- Tracking GPS saat aplikasi di latar belakang / layar mati (butuh foreground service).
- Fitur koordinator (tim hari ini, setoran), izin/sakit, pengumuman & notifikasi.
- Pembatalan order dari aplikasi (API `POST /sales/{id}/void` sudah ada).
- Aturan poin produk fokus (server masih mengirim 0).
