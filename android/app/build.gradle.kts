import java.io.File
import java.util.Properties
import org.gradle.api.GradleException

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ---------------------------------------------------------------------------
// Release signing.
//
// Android only lets a new APK update an installed app when both use the same
// application id (set below) *and* the same signing key. To keep that true for
// every build, configure one keystore and reuse it everywhere. Values are read
// from android/key.properties (gitignored) first, then from environment
// variables (used by CI).
// ---------------------------------------------------------------------------
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

val signingValue: (String, String) -> String? = { property, environment ->
    (keystoreProperties.getProperty(property) ?: System.getenv(environment))
        ?.takeIf { it.isNotBlank() }
}

val releaseStoreFile: File? =
    signingValue("storeFile", "ANDROID_KEYSTORE_PATH")?.let { file(it) }
val releaseStorePassword: String? = signingValue("storePassword", "ANDROID_KEYSTORE_PASSWORD")
val releaseKeyAlias: String? = signingValue("keyAlias", "ANDROID_KEY_ALIAS")
val releaseKeyPassword: String? = signingValue("keyPassword", "ANDROID_KEY_PASSWORD")

val hasReleaseSigning: Boolean =
    releaseStoreFile?.exists() == true &&
        releaseStorePassword != null &&
        releaseKeyAlias != null &&
        releaseKeyPassword != null

android {
    namespace = "com.bramve.jangla"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // NOTE: Using Kotlin compilerOptions DSL instead of deprecated kotlinOptions.jvmTarget.
    defaultConfig {
        // Keep this stable: changing it makes Android treat the app as a
        // different app and refuse in-place updates.
        applicationId = "com.bramve.jangla"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = releaseStoreFile
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig =
                if (hasReleaseSigning) {
                    signingConfigs.getByName("release")
                } else {
                    // Placeholder only; the guard below stops a release build
                    // from actually being packaged with the debug key.
                    signingConfigs.getByName("debug")
                }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}

// Refuse to package a release APK without a real keystore. Silently signing
// with the debug key produces an APK that cannot update a properly signed
// install, which is exactly the "must uninstall first" problem.
tasks.matching { it.name == "assembleRelease" || it.name == "bundleRelease" }.configureEach {
    doFirst {
        if (!hasReleaseSigning) {
            throw GradleException(
                """
                Release signing is not configured, so this APK could not update an
                installed copy of the app (Android requires the same signing key).

                Set it up once:
                  1) keytool -genkey -v -keystore ~/jangla-upload.jks -keyalg RSA \
                       -keysize 2048 -validity 10000 -alias upload
                  2) Copy android/key.properties.example to android/key.properties
                     and fill in storeFile / storePassword / keyAlias / keyPassword
                     (or set ANDROID_KEYSTORE_PATH, ANDROID_KEYSTORE_PASSWORD,
                     ANDROID_KEY_ALIAS, ANDROID_KEY_PASSWORD).

                See README.md ("Installing Android updates").
                """.trimIndent(),
            )
        }
    }
}
