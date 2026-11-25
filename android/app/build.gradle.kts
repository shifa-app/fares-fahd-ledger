plugins {
    id("com.android.application")
    // Google Services (cloud backup sign-in): reads google-services.json
    // from android/app/. Until that file is placed (see README),
    // the Google Services task fails the build — by design, so a
    // missing setup can never ship silently as «working».
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.faresfahd.ledger"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.faresfahd.ledger"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Pinned signing key: the project-local copy of the debug
    // keystore (android/debug.keystore, SHA-1 87:34:7D:…:86:D3 —
    // the fingerprint registered in Firebase / Google OAuth).
    // Builds must never resolve the keystore from the builder's
    // home directory again: that keystore was recreated once
    // (24/11) and silently changed the fingerprint, which broke
    // Google sign-in with code 10. The keystore file itself is
    // excluded from git (see .gitignore) — the repo is public.
    signingConfigs {
        create("pinnedDebug") {
            storeFile = rootProject.file("debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
    }

    buildTypes {
        release {
            // Signed with the pinned keystore above, so every
            // future build keeps the same SHA-1 fingerprint.
            signingConfig = signingConfigs.getByName("pinnedDebug")
        }
    }

    // Release lint ("lintVital") crashes inside Lint's own JavaDoc parser
    // on a dependency's sources (AGP 9.3.1 + JDK 17) — a tooling crash,
    // not a code issue. Dart is already covered by `flutter analyze`.
    lint {
        checkReleaseBuilds = false
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
