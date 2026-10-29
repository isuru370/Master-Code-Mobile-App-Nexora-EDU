# nexorait_education_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Building: one app for every institute

The app no longer needs one build per institute. On first start it shows
**Connect to your institute**. Staff scan the **Staff App QR** from the
institute website (Admin > Staff App QR), confirm the institute name, then
sign in. The QR is checked twice: the app accepts only `https://*.nexorait.lk`,
and that server must accept the QR's key.

Play Store (one upload, every institute):

```
flutter build appbundle --release --obfuscate --split-debug-info=build/debug-info --build-name=1.1.0 --build-number=26103001
```

- Raise `--build-number` on every release. Use the date and a counter (yyMMddNN), e.g. `26103001`.
- Leave out `API_BASE_URL`. The home-screen name is `NexoraEdu`, or set `--dart-define=APP_NAME=...`.

The old one-institute build still works and skips the QR:

```
flutter build apk --release --split-per-abi --dart-define=API_BASE_URL=https://savidyaedu.nexorait.lk --dart-define=APP_NAME=SAVIDYAEDU
```

Debug builds may also scan a local test server's QR (http / IP address).
