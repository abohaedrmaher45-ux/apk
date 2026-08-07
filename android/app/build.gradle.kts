plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "de.sentrytech.ourfamily"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.3.13750724"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    // ── إصلاح فشل بناء release ──
    // إضافة flutter_local_notifications تطلب desugar_jdk_libs:1.2.2 (نسخة
    // محذوفة من مستودع Google) أثناء مهمة generateReleaseLintModel، فيفشل
    // البناء. تعطيل lint في release يتجاوز المهمة الفاشلة دون التأثير على
    // التطبيق النهائي.
    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "de.sentrytech.ourfamily"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = 246
        versionName = "2.4.6"
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}

configurations.all {
    exclude(group = "com.google.firebase", module = "firebase-iid")

    // ── توحيد نسخة desugar_jdk_libs ──
    // بعض الإضافات (مثل flutter_local_notifications) تطلب النسخة المحذوفة
    // 1.2.2؛ نُجبر Gradle على استخدام 2.1.4 المتوفرة والمتوافقة.
    resolutionStrategy {
        force("com.android.tools:desugar_jdk_libs:2.1.4")
    }
}

dependencies {
    implementation("androidx.constraintlayout:constraintlayout:2.1.4")
    implementation("com.google.android.material:material:1.12.0")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}