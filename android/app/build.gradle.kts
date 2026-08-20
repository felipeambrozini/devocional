// Sem o plugin "com.google.gms.google-services" de propósito: a conta na
// nuvem (lib/data/nuvem.dart) só existe na web, `nuvemSuportada => kIsWeb`.
// `flutterfire configure` tinha registrado um app Android e gerado
// google-services.json, mas o Android nunca chama Firebase.initializeApp — e
// deixar o plugin exigiria manter esse arquivo em sincronia com o
// applicationId (ele falha o build se o "package_name" não bater). Removido
// junto com google-services.json.
plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.appdistribution")
}

android {
    namespace = "com.felipeambrozini.devocional"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // flutter_local_notifications usa APIs de java.time por baixo, e o
        // Gradle recusa o AAR sem isto ligado (checkDebugAarMetadata falha
        // dizendo que a dependência exige desugaring da biblioteca core).
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.felipeambrozini.devocional"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            storeFile = file("upload-keystore.jks")
            storePassword = System.getenv("KEYSTORE_PASSWORD") ?: ""
            keyAlias = "upload"
            keyPassword = System.getenv("KEY_PASSWORD") ?: ""
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

firebaseAppDistribution {
    appId = "1:169480227109:android:286f46640a25846c3c72cc"
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
