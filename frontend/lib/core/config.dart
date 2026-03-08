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
  // Optional hard override at run/build time:
  // flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
  static const String _baseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
  static const String _envOverride = String.fromEnvironment(
    'API_ENV',
    defaultValue: '',
  );

  // Auto mode chooses a sensible default per runtime target.
  // Override with API_BASE_URL when needed.
  static AppEnvironment env = _resolveDefaultEnv();

  static const localhostBaseUrl = 'http://localhost:8080';
  // Android emulator maps host machine localhost through 10.0.2.2.
  static const androidEmulatorBaseUrl = 'http://10.0.2.2:8080';
  // Replace this if your LAN IP changes.
  static const physicalDeviceBaseUrl = 'http://192.168.1.20:8080';
  static const productionBaseUrl = 'https://example.com'; // TODO

  static AppEnvironment _resolveDefaultEnv() {
    final override = _parseEnvironment(_envOverride);
    if (override != null) {
      return override;
    }

    // Most local Android runs are on a physical phone; avoid emulator-only
    // routing unless explicitly requested via API_ENV or API_BASE_URL.
    if (kDebugMode && defaultTargetPlatform == TargetPlatform.android) {
      return AppEnvironment.physicalDevice;
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
    if (_baseUrlOverride.isNotEmpty) {
      return _baseUrlOverride;
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
