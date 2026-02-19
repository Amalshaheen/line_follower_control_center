plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.line_follower_control_center"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.line_follower_control_center"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 31
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Signing configuration disabled for development
        // create("release") {
        //     storeFile = file("keystore.jks")
        //     storePassword = System.getenv("KEYSTORE_PASSWORD")
        //     keyAlias = System.getenv("KEYSTORE_ALIAS")
        //     keyPassword = System.getenv("KEYSTORE_ALIAS_PASSWORD")
        // }
    }

    buildTypes {
        getByName("release") {
            // signingConfig = signingConfigs.getByName("release")
            
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    lintOptions {
        disable("ResourceType", "MissingDimensResource")
    }

    dependenciesInfo {
        includeInApk = false
        includeInBundle = false
    }
}

gradle.projectsEvaluated {
    rootProject.subprojects {
        if (name == "flutter_bluetooth_serial") {
            tasks.forEach { task ->
                if (task.name == "verifyReleaseResources") {
                    task.enabled = false
                }
            }
        }
    }
}

dependencies {
    implementation("com.google.android.material:material:1.11.0")
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("androidx.compose.material3:material3:1.3.0")
}

flutter {
    source = "../.."
}
