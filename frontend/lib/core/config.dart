enum AppEnvironment { mock, androidEmulator, physicalDevice, production }

class AppConfig {
  static AppEnvironment env = AppEnvironment.mock; // default for UI-only dev

  static const androidEmulatorBaseUrl = 'http://10.0.2.2:8000';
  static const physicalDeviceBaseUrl = 'http://192.168.1.100:8000'; // TODO replace with PC LAN IP when needed
  static const productionBaseUrl = 'https://example.com'; // TODO

  static String get baseUrl {
    switch (env) {
      case AppEnvironment.mock:
        return '';
      case AppEnvironment.androidEmulator:
        return androidEmulatorBaseUrl;
      case AppEnvironment.physicalDevice:
        return physicalDeviceBaseUrl;
      case AppEnvironment.production:
        return productionBaseUrl;
    }
  }
}
