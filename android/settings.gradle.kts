pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
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
    id("com.android.application") version "9.0.1" apply false
    // START: FlutterFire Configuration
    id("com.google.gms.google-services") version("4.4.4") apply false
    // END: FlutterFire Configuration
    // Flutter's Gradle plugin still applies this classic Kotlin plugin internally
    // (see comment in gradle.properties on android.builtInKotlin/newDsl). Pin the
    // version explicitly — otherwise it resolves to an older default that Flutter
    // warns will stop being supported.
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
}

include(":app")
