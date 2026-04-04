pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        val propertiesFile = file("local.properties")
        if (propertiesFile.exists()) {
            propertiesFile.inputStream().use { properties.load(it) }
        }
        val settingsSdkPath = properties.getProperty("flutter.sdk")
        settingsSdkPath ?: System.getenv("FLUTTER_ROOT") ?: throw GradleException("Flutter SDK not found. Define flutter.sdk in local.properties or set FLUTTER_ROOT env variable.")
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.7.2" apply false
    id("org.jetbrains.kotlin.android") version "2.0.21" apply false
}

include(":app")