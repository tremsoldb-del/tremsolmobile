import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")

    // Flutter must be applied after the Android and Kotlin plugins.
    id("dev.flutter.flutter-gradle-plugin")

    // Required for Firebase.
    id("com.google.gms.google-services")
}

/*
 * Load Tremsol's private signing credentials from:
 * android/key.properties
 */
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")

if (!keystorePropertiesFile.exists()) {
    throw GradleException(
        "Missing android/key.properties. " +
            "Configure Tremsol's Google Play upload key before building."
    )
}

keystoreProperties.load(FileInputStream(keystorePropertiesFile))

android {
    namespace = "com.ezitraid.tremsol"

    // Android 16 / API level 36.
    compileSdk = 36

    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Required by flutter_local_notifications.
        isCoreLibraryDesugaringEnabled = true

        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.ezitraid.tremsol"

        minSdk = flutter.minSdkVersion

        // Android 16 / API level 36.
        targetSdk = 36

        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String
        }
    }

    buildTypes {
        release {
            // Sign Tremsol releases with the registered Google Play upload key.
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Required for Java 8+ API desugaring.
    coreLibraryDesugaring(
        "com.android.tools:desugar_jdk_libs:2.1.4"
    )
}