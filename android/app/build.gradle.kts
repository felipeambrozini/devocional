// O plugin "com.google.gms.google-services" lê google-services.json (neste
// diretório) e injeta a configuração do Firebase no build do Android. É
// necessário porque o Android também usa Firebase: `nuvemSuportada` em
// lib/data/nuvem.dart é `true` em toda plataforma, não só na web, então
// main.dart chama `Nuvem.instancia.iniciar(estado)` (Auth + Firestore) no
// Android também; e `firebase_messaging` (lib/data/lembretes.dart) usa a
// mesma configuração para o lembrete diário por push. O arquivo precisa
// continuar em sincronia com o applicationId abaixo — o plugin falha o build
// se o "package_name" dele não bater.
plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.felipeambrozini.devocional"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // Alguma dependência (Firebase incluso) usa APIs de java.time por
        // baixo, e o Gradle recusa o AAR sem isto ligado (checkDebugAarMetadata
        // falha dizendo que a dependência exige desugaring da biblioteca core).
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
            storeType = "PKCS12"
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
