# frontend

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## API Base URL (No Hardcoded LAN IP)

This project does not require committing a machine-specific API IP address.

- Android emulator default: `http://10.0.2.2:8080`
- Localhost fallback: `http://localhost:8080`
- Physical phone (recommended): pass runtime define

Examples:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8080
```

Run on a specific device with Flutter's `-d` option:

```bash
cd frontend
flutter run -d emulator-5554
```

Passing the device id without `-d` makes Flutter treat it as a target file.

Or use the dynamic helper script (auto-detects your current host LAN IP and sets `adb reverse` when a device is connected):

```bash
cd frontend
./scripts/run_phone.sh
```

The helper also accepts the device id and can be launched from the repository root:

```bash
frontend/scripts/run_phone.sh -d emulator-5554
frontend/scripts/run_phone.sh --device adb-XKAES86TEUNBQOPN-U38ttB._adb-tls-connect._tcp
```

Optional overrides:

```bash
API_HOST=192.168.x.x API_PORT=8080 ./scripts/run_phone.sh
```
