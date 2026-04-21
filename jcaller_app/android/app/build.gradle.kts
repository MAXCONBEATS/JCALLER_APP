plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    compileSdk = 34                     // <-- SDK версия

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_1_8.toString()
    }

    defaultConfig {
        applicationId = "com.yourcompany.jcaller_app"
        minSdk = 21                     // <-- Для WebRTC нужно API 21+
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"
    }
}