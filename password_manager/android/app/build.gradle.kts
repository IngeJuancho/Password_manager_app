plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.password_manager"
    compileSdk = flutter.compileSdkVersion

    // Aquí se corrige la versión del NDK
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // Application ID
        applicationId = "com.password.manager"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = 10
        versionName = "2.7.1"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // --- NUEVO CÓDIGO PARA RENOMBRAR EL APK (Kotlin DSL) ---
    applicationVariants.all {
        val variant = this
        outputs.all {
            // En Kotlin DSL necesitamos verificar el tipo para acceder a outputFileName
            if (this is com.android.build.gradle.internal.api.BaseVariantOutputImpl) {
                // Opción A: Nombre fijo
                outputFileName = "Password Manager.apk"
                
                // Opción B: Nombre con versión (ej: SecureVault-v2.7.apk) - Si prefieres esta, descomenta:
                // outputFileName = "SecureVault-v${variant.versionName}.apk"
            }
        }
    }
    // -------------------------------------------------------
}

flutter {
    source = "../.."
}
