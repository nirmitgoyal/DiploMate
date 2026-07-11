import java.util.Properties

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { load(it) }
    }
}

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.diplomate.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications 17.x uses java.time; AGP requires
        // desugaring for it below API 26.
        isCoreLibraryDesugaringEnabled = true
    }

    // AGP 8+ defaults buildConfig generation off; MainActivity reads
    // BuildConfig.DEBUG to gate FLAG_SECURE, so re-enable it here.
    buildFeatures {
        buildConfig = true
    }

    defaultConfig {
        // Permanent id - enrolled in Play Console and Google OAuth clients.
        // Never change after the first Play upload.
        applicationId = "com.diplomate.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
            // No else: a guard task below fails release builds instead of
            // letting them debug-sign or emit an unsigned artifact.
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// Release artifacts must never fall back to debug signing: the first Play
// upload permanently enrolls the upload key. Fail with a pointer instead.
//
// This hooks the whole task graph (not doFirst on assembleRelease/bundleRelease
// themselves): those two are lifecycle tasks whose real work happens in
// upstream dependencies (packageRelease, packageReleaseBundle/signReleaseBundle)
// that already run - and already write an unsigned artifact to disk - before
// the lifecycle task's own doFirst would fire. whenReady runs once the full
// graph is resolved but before any task executes, so it blocks those
// upstream tasks too.
gradle.taskGraph.whenReady {
    val requestsRelease = allTasks.any { it.name == "assembleRelease" || it.name == "bundleRelease" }
    if (requestsRelease && !keystorePropertiesFile.exists()) {
        throw GradleException(
            "android/key.properties not found - release builds must be signed " +
                "with the upload keystore. See docs/android-release-runbook.md."
        )
    }
}
