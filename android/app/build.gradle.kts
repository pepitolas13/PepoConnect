import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing: android/key.properties (git-ignored, see key.properties.example).
// storeFile may be absolute or relative to android/app.
val keystorePropertiesFile: File = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseKeystore: Boolean = keystorePropertiesFile.isFile
if (hasReleaseKeystore) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

android {
    namespace = "org.pepoconnect.app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications needs core library desugaring (java.time).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "org.pepoconnect.app"
        minSdk = 29
        targetSdk = 36
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                val storeFilePath = keystoreProperties.getProperty("storeFile")
                    ?: error("android/key.properties: storeFile is missing")
                val candidate = File(storeFilePath)
                storeFile = if (candidate.isAbsolute) candidate else file(storeFilePath)
                storePassword = keystoreProperties.getProperty("storePassword")
                    ?: error("android/key.properties: storePassword is missing")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                    ?: error("android/key.properties: keyAlias is missing")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                    ?: error("android/key.properties: keyPassword is missing")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                logger.warn(
                    "PepoConnect: android/key.properties not found, signing the release build " +
                        "with the DEBUG key. Copy android/key.properties.example to android/key.properties " +
                        "for a distributable build."
                )
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    testImplementation("junit:junit:4.13.2")
    // Required by flutter_local_notifications 10+ (java.time backport).
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Recommended by flutter_local_notifications to avoid crashes on Android 12L+ when desugaring.
    implementation("androidx.window:window:1.0.0")
    implementation("androidx.window:window-java:1.0.0")
}
