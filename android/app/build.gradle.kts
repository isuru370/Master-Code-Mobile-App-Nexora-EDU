import java.io.FileInputStream
import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing key (see docs/RELEASE.md).
// android/key.properties and the .jks file are NOT committed (.gitignore).
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// --dart-define values (Flutter passes them base64 encoded as "dart-defines")
// APP_NAME = the app name on the phone's home screen, e.g. MihisaraEdu:
//   flutter build apk --dart-define=API_BASE_URL=https://... --dart-define=APP_NAME=MihisaraEdu
val dartDefines: Map<String, String> = (project.findProperty("dart-defines") as String?)
    ?.split(",")
    ?.mapNotNull { encoded ->
        runCatching { String(Base64.getDecoder().decode(encoded), Charsets.UTF_8) }.getOrNull()
    }
    ?.mapNotNull { pair ->
        val i = pair.indexOf('=')
        if (i > 0) pair.substring(0, i) to pair.substring(i + 1) else null
    }
    ?.toMap()
    ?: emptyMap()

android {
    namespace = "com.nexorait.master_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.nexorait.master_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // AndroidManifest android:label="${appLabel}"
        manifestPlaceholders["appLabel"] = dartDefines["APP_NAME"]?.takeIf { it.isNotBlank() } ?: "NexoraEdu"
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            // Real release key when android/key.properties exists,
            // otherwise the debug key so `flutter run --release` still works.
            if (!keystorePropertiesFile.exists()) {
                logger.warn(
                    "WARNING: android/key.properties not found - this RELEASE build is signed " +
                        "with the DEBUG key. Do not upload it to Play Store or give it to users: " +
                        "a later build signed with the real key cannot update it."
                )
            }
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
