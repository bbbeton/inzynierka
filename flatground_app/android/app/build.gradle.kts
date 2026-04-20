plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.flatground_app"
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
        applicationId = "com.example.flatground_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

configurations.all {
    resolutionStrategy {
        // Force TensorFlow Lite Select TF Ops version to ensure compatibility
        force("org.tensorflow:tensorflow-lite-select-tf-ops:+")
    }
}

flutter {
    source = "../.."
}

dependencies {
    // TensorFlow Lite Select TF Ops for models using Select TensorFlow ops
    // This enables support for models that use Select TensorFlow operations (Flex ops)
    // The Select TF Ops library must be included for models with Flex operations
    // Version 2.13.0 is forced via resolutionStrategy above
    implementation("org.tensorflow:tensorflow-lite-select-tf-ops:+")
    implementation("androidx.multidex:multidex:2.0.1")
}