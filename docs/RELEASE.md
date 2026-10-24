# Building a release APK

## 1. Server address (`--dart-define`)

The API address is no longer edited in code. Pass it when you run or build:

```bash
# Local network server (laptop running `php artisan serve --host=0.0.0.0`)
flutter run --dart-define=API_BASE_URL=http://10.17.162.230:8000

# Production
flutter build apk --release --dart-define=API_BASE_URL=https://mihisaraeducation.nexorait.lk
```

Without `--dart-define` the default in `lib/core/constants/api_constants.dart` is used.

> Do not end the URL with `/` (the app adds `/api` itself).

### App name on the phone (`APP_NAME`)

The name under the icon is fixed when the APK is built. Use the institute's short name (`GET /api/institute` → `short_name`, e.g. *Mihisara Education Institute* → `MihisaraEdu`):

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://mihisaraeducation.nexorait.lk --dart-define=APP_NAME=MihisaraEdu
```

Without it the name is `NexoraEdu`.

The institute name, tagline and logo on the splash / login screens and on printed receipts come from the server (`INSTITUTE_NAME`, `INSTITUTE_TAGLINE`, `INSTITUTE_LOGO` in its `.env`) and are saved on the phone, so they need no build.

## 2. Release signing key (one time)

Create the key (keep the `.jks` file and passwords safe; losing them means the
app can never be updated on the same install / Play Store listing):

```bash
keytool -genkey -v -keystore %USERPROFILE%\nexora-release.jks ^
  -keyalg RSA -keysize 2048 -validity 10000 -alias nexora
```

Create `android/key.properties` (already in `.gitignore`, never commit it):

```properties
storePassword=<password>
keyPassword=<password>
keyAlias=nexora
storeFile=C:\\Users\\<you>\\nexora-release.jks
```

When `android/key.properties` exists the release build is signed with this key;
otherwise it falls back to the debug key (fine for testing, not for publishing).

## 3. Build

```bash
flutter clean
flutter pub get
flutter build apk --release --dart-define=API_BASE_URL=https://mihisaraeducation.nexorait.lk --dart-define=APP_NAME=MihisaraEdu
# APK: build/app/outputs/flutter-apk/app-release.apk
```

## Notes

- `android/app/src/main/res/xml/network_security_config.xml` allows `http://`
  so the app can reach a local server in release builds. When only the HTTPS
  server is used, set `cleartextTrafficPermitted="false"` there.
- Release builds do not print `debugPrint` output (API responses contain
  student data).
