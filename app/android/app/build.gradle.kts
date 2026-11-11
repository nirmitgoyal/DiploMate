import java.net.URI
import java.util.Base64
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

    // A Play bundle must have working production auth configuration. Keep
    // assembleRelease available for the runbook's local device smoke tests.
    if (allTasks.any { it.path == ":app:bundleRelease" }) {
        val defines = providers.gradleProperty("dart-defines").orNull.orEmpty()
            .split(",")
            .filter { it.isNotEmpty() }
            .associate {
                val entry = String(Base64.getDecoder().decode(it), Charsets.UTF_8)
                entry.substringBefore("=") to entry.substringAfter("=", "")
            }
        val apiUrl = defines["API_BASE_URL"]?.let {
            runCatching { URI(it) }.getOrNull()
        }
        if (apiUrl?.scheme != "https" || apiUrl.host.isNullOrBlank() ||
            apiUrl.userInfo != null || apiUrl.query != null || apiUrl.fragment != null
        ) {
            throw GradleException(
                "Play bundles require an HTTPS API_BASE_URL. See docs/android-release-runbook.md."
            )
        }
        val clientId = defines["GOOGLE_SERVER_CLIENT_ID"].orEmpty()
        if (!clientId.matches(Regex("""[0-9]+-[A-Za-z0-9_-]+\.apps\.googleusercontent\.com"""))) {
            throw GradleException(
                "Play bundles require GOOGLE_SERVER_CLIENT_ID set to the Google web OAuth client ID. " +
                    "See docs/android-release-runbook.md."
            )
        }
        if (defines["DEV_FAKE_AUTH"] == "true") {
            throw GradleException("Play bundles cannot use DEV_FAKE_AUTH.")
        }
    }
}
