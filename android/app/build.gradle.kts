import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "de.icd360sev.schatzmeister"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "de.icd360sev.schatzmeister"
        minSdk = 24 // Required for WebRTC
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // MultiDex support for large apps
        multiDexEnabled = true

        // ⚠️ Ohne das hier reicht `--target-platform android-arm64` NICHT.
        //
        // Nachgemessen am 23.08.2026 an dieser App: mit dem Schalter allein
        // kam ein APK von 74 MB heraus, in dem armeabi-v7a und x86_64
        // weiterhin steckten. Der Schalter steuert nur, fuer welche
        // Architekturen FLUTTER seinen Dart-Code uebersetzt (libapp.so) —
        // die fertig mitgelieferten Bibliotheken der Plugins packt das
        // Android Gradle Plugin unabhaengig davon fuer alles ein.
        //
        // Uebernommen aus der Vorsitzer-App, wo derselbe Befund schon am
        // 19.08.2026 gemessen und geloest wurde.
        ndk {
            abiFilters += "arm64-v8a"
        }
    }

    // ⚠️ ndk.abiFilters allein reicht AUCH nicht. In der Vorsitzer-App blieben
    // damit 22,1 MB uebrig — vor allem libjingle_peerconnection (WebRTC) fuer
    // x86_64 und armeabi-v7a. Solche Dateien kommen als fertige Bibliotheken
    // aus AAR-Abhaengigkeiten (WebRTC, CameraX, DataStore); abiFilters greift
    // dort nicht zuverlaessig, die Ausnahme beim Packen dagegen wirkt
    // unabhaengig davon, woher eine Datei stammt.
    //
    // Beides steht bewusst nebeneinander: abiFilters fuer alles, was wir
    // selbst bauen, die Ausnahme als letzte Instanz vor dem Zippen.
    packaging {
        jniLibs {
            excludes += setOf(
                "lib/x86/**",
                "lib/x86_64/**",
                "lib/armeabi-v7a/**",
            )
        }
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

            // Enable ProGuard/R8 for release builds
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
