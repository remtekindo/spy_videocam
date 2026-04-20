plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // 1. NAIKKAN KE 36 UNTUK MENGATASI ERROR BUILD
    namespace = "com.remtekindo.cctv"
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        applicationId = "com.remtekindo.cctv"
        // 2. MIN SDK TETAP 24 AGAR BISA JALAN DI HP LAMA
        minSdk = 24
        // 3. TARGET SDK BISA DI 34 ATAU 35
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.multidex:multidex:2.0.1")
}