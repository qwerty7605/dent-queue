enum AppEnvironment { mock, androidEmulator, physicalDevice, production }

class AppConfig {
  // 👇 set to the correct environment before building/running
  static AppEnvironment env = AppEnvironment.physicalDevice; // change to emulator/production as needed

  // use port 8080 since nginx/docker expose that
  static const androidEmulatorBaseUrl = 'http://80:8080';
  // replace 192.168.1.20 with your PC's actual LAN IP
  static const physicalDeviceBaseUrl = 'http://192.168.1.20:8080';
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
