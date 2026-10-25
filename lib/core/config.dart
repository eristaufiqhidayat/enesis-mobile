/// Pengaturan build. Ubah tanpa mengedit kode:
/// `flutter run --dart-define=API_BASE_URL=https://enesis.lembaharafah.com/api/mobile/v1`
class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://enesis.lembaharafah.com/api/mobile/v1',
  );

  /// Harus sama dengan `version` di pubspec.yaml (dikirim sebagai header X-App-Version).
  static const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '1.1.0');

  static const requestTimeout = Duration(seconds: 20);
}
