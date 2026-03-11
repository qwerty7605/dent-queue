import 'package:flutter/foundation.dart';

enum AppEnvironment {
  mock,
  auto,
  localhost,
  androidEmulator,
  physicalDevice,
  production,
}

class AppConfig {
  // Optional overrides at run/build time:
  // 1) Full URL override:
  // flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8080
  // 2) Host/port override:
  // flutter run --dart-define=API_HOST=192.168.x.x --dart-define=API_PORT=8080
  static const String _baseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
  static const String _hostOverride = String.fromEnvironment(
    'API_HOST',
    defaultValue: '',
  );
  static const String _portOverride = String.fromEnvironment(
    'API_PORT',
    defaultValue: '8080',
  );
  static const String _envOverride = String.fromEnvironment(
    'API_ENV',
    defaultValue: '',
  );

  static const int defaultPort = 8080;

  // Auto mode chooses a sensible default per runtime target.
  // Override with API_BASE_URL/API_HOST when needed.
  static AppEnvironment env = _resolveDefaultEnv();

  static String get localhostBaseUrl => 'http://localhost:$port';
  // Android emulator maps host machine localhost through 10.0.2.2.
  static String get androidEmulatorBaseUrl => 'http://10.0.2.2:$port';
  // Physical-device fallback prefers localhost, which works with adb reverse.
  // For Wi-Fi device testing, pass API_BASE_URL/API_HOST at runtime.
  static String get physicalDeviceBaseUrl => 'http://192.168.1.20:80';
  static const productionBaseUrl = 'https://example.com'; // TODO

  static int get port => int.tryParse(_portOverride) ?? defaultPort;

  static bool get hasManualBaseUrl =>
      _baseUrlOverride.trim().isNotEmpty || _hostOverride.trim().isNotEmpty;

  static String? _normalizeUrl(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    return trimmed.endsWith('/') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
  }

  static String? get manualBaseUrl {
    final full = _normalizeUrl(_baseUrlOverride);
    if (full != null) return full;

    final host = _hostOverride.trim();
    if (host.isEmpty) return null;

    final hostUri = Uri.tryParse(host);
    if (hostUri != null && hostUri.hasScheme) {
      if (hostUri.hasPort) return _normalizeUrl(host);
      final rebuilt = Uri(
        scheme: hostUri.scheme,
        host: hostUri.host,
        port: port,
        path: hostUri.path,
      );
      return _normalizeUrl(rebuilt.toString());
    }

    return _normalizeUrl('http://$host:$port');
  }

  static AppEnvironment _resolveDefaultEnv() {
    final override = _parseEnvironment(_envOverride);
    if (override != null) {
      return override;
    }

    return AppEnvironment.auto;
  }

  static AppEnvironment? _parseEnvironment(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'mock':
        return AppEnvironment.mock;
      case 'auto':
        return AppEnvironment.auto;
      case 'localhost':
        return AppEnvironment.localhost;
      case 'androidemulator':
      case 'emulator':
        return AppEnvironment.androidEmulator;
      case 'physicaldevice':
      case 'physical':
        return AppEnvironment.physicalDevice;
      case 'production':
      case 'prod':
        return AppEnvironment.production;
      default:
        return null;
    }
  }

  static String get baseUrl {
    final manual = manualBaseUrl;
    if (manual != null) {
      return manual;
    }

    switch (env) {
      case AppEnvironment.mock:
        return '';
      case AppEnvironment.auto:
        if (defaultTargetPlatform == TargetPlatform.android) {
          return androidEmulatorBaseUrl;
        }
        return localhostBaseUrl;
      case AppEnvironment.localhost:
        return localhostBaseUrl;
      case AppEnvironment.androidEmulator:
        return androidEmulatorBaseUrl;
      case AppEnvironment.physicalDevice:
        return physicalDeviceBaseUrl;
      case AppEnvironment.production:
        return productionBaseUrl;
    }
  }
}
