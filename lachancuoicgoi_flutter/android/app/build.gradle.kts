import java.util.Properties

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use(::load)
    }
}

android {
    namespace = "com.lachancuocgoi.lachancuocgoi_flutter"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.lachancuocgoi.lachancuocgoi_flutter"
        minSdk = 26
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    androidResources {
        noCompress += listOf("tflite", "vosk", "model-vn")
    }

    buildFeatures {
        buildConfig = true
    }

    testOptions {
        unitTests.isIncludeAndroidResources = true
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
    // BLOCKER: libvosk.so in 0.3.75 is 4 KiB-aligned. Google Play requires
    // 16 KiB for Android 15+ submissions (Nov 2025). 0.3.75 is the latest
    // public release — no 16 KiB build exists. Options:
    //   1) Build a custom AAR from Vosk C++ source using NDK r28+ with
    //      -Wl,-z,max-page-size=16384
    //   2) Wait for alphacephei to release a 16 KiB-aligned artifact.
    // Verify after build: dart run tool/verify_16kb_alignment.dart <apk>
    implementation("com.alphacephei:vosk-android:0.3.75")

    testImplementation("junit:junit:4.13.2")
    testImplementation("io.mockk:mockk:1.13.12")
    testImplementation("org.mockito:mockito-core:5.14.2")
    testImplementation("org.robolectric:robolectric:4.12.2")
    testImplementation("androidx.test:core:1.6.1")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.8.1")

    // Versions pinned to match `androidx.test:core:1.6.1`'s strict-constraint
    // requirements (core 1.6.1 transitively forces runner/rules 1.2.0 and
    // espresso-core 3.2.0 via consistent resolution). Newer versions cause
    // "Cannot find a version that satisfies the version constraints".
    androidTestImplementation("androidx.test.ext:junit:1.1.5")
    androidTestImplementation("androidx.test:runner:1.2.0")
    androidTestImplementation("androidx.test:rules:1.2.0")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.2.0")
    androidTestImplementation("androidx.test.espresso:espresso-contrib:3.2.0")
    androidTestImplementation("androidx.test.espresso:espresso-intents:3.2.0")
    androidTestImplementation("androidx.test.uiautomator:uiautomator:2.2.0")
    androidTestImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.8.1")
}

flutter {
    source = "../.."
}

gradle.taskGraph.whenReady {
    val requiresReleaseSigning = allTasks.any {
        it.name.contains("Release", ignoreCase = true)
    }
    if (requiresReleaseSigning && !keystorePropertiesFile.exists()) {
        throw GradleException(
            "Missing android/key.properties for release signing. " +
                "Create it with storePassword, keyPassword, keyAlias, and storeFile.",
        )
    }
}
