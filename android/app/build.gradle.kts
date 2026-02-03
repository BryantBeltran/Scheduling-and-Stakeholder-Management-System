// Run commands:
//   flutter run --flavor dev -t lib/main_dev.dart
//   flutter run --flavor staging -t lib/main_staging.dart
//   flutter run --flavor prod -t lib/main_prod.dart

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Google Services plugin for Firebase
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.scheduling_and_stakeholder_management_system"
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
        applicationId = "com.example.scheduling_and_stakeholder_management_system"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Define flavor dimensions
    // Reference: https://developer.android.com/build/build-variants#flavor-dimensions
    flavorDimensions += "environment"

    // Product flavors for different environments
    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            // Resource values accessible in Android code
            resValue("string", "app_name", "SSMS Dev")
        }
        
        create("staging") {
            dimension = "environment"
            applicationIdSuffix = ".staging"
            versionNameSuffix = "-staging"
            resValue("string", "app_name", "SSMS Staging")
        }
        
        create("prod") {
            dimension = "environment"
            // No suffix for production - uses base applicationId
            resValue("string", "app_name", "Scheduling & Stakeholder")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            
            // Enable code shrinking for release builds
            // isMinifyEnabled = true
            // isShrinkResources = true
            // proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
        
        debug {
            // Debug builds are automatically signed with debug key
            // Only dev/staging get .debug suffix
        }
    }
    
    // Configure debug suffix only for dev and staging flavors
    applicationVariants.all {
        val flavor = productFlavors[0].name
        if (flavor == "dev" || flavor == "staging") {
            if (buildType.name == "debug") {
                outputs.forEach { output ->
                    if (output is com.android.build.gradle.internal.api.ApkVariantOutputImpl) {
                        output.outputFileName = output.outputFileName.replace(".apk", "-debug.apk")
                    }
                }
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Import the Firebase BoM
    implementation(platform("com.google.firebase:firebase-bom:34.8.0"))

    // Firebase products - versions managed by BoM
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
    implementation("com.google.firebase:firebase-storage")
}
