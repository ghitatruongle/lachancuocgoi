import java.util.Properties

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localProperties.load(localPropertiesFile.inputStream())
}

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("com.google.devtools.ksp")
    alias(libs.plugins.compose.compiler)
}

android {
    namespace = "com.example.lachancuocgoi"
    compileSdk = 34

    // Bắt buộc: không nén file .tflite và thư mục model Vosk để load trực tiếp từ assets
    androidResources {
        noCompress += "tflite"
        noCompress += "model-vn"
    }

    defaultConfig {
        applicationId = "com.lachancuocgoi.app"
        minSdk = 26
        targetSdk = 34
        versionCode = 8
        versionName = "BETA 1.3"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        vectorDrawables {
            useSupportLibrary = true
        }

        val apiKeysString = localProperties.stringPropertyNames()
            .filter { it.startsWith("GEMINI_API_KEY_") }
            .mapNotNull { keyName ->
                val number = keyName.substringAfter("GEMINI_API_KEY_").toIntOrNull()
                if (number != null) {
                    val rawValue = localProperties.getProperty(keyName)
                    val cleanValue = rawValue.substringBefore("#").trim().removeSurrounding("\"")
                    number to cleanValue
                } else {
                    null
                }
            }
            .sortedBy { it.first }
            .map { it.second }
            .filter { it.isNotBlank() }
            .joinToString(",")

        buildConfigField("String", "GEMINI_API_KEYS", "\"$apiKeysString\"")
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    // NOTE: kotlinOptions deprecated từ AGP 9.x nhưng vẫn hoạt động cho đến AGP 10.0
    // Không thể dùng top-level kotlin{} vì conflict với org.jetbrains.kotlin.android plugin
    @Suppress("DEPRECATION")
    kotlinOptions {
        jvmTarget = "17"
    }
    buildFeatures {
        compose = true
        buildConfig = true
    }
    testOptions {
        unitTests.isReturnDefaultValues = true
        unitTests.all {
            it.jvmArgs("-Dnet.bytebuddy.experimental=true")
        }
    }
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

ksp {
    arg("room.schemaLocation", "$projectDir/schemas")
}

dependencies {
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("com.google.android.material:material:1.11.0")
    implementation("androidx.compose.material:material-icons-extended-android:1.6.7")
    implementation("androidx.core:core-splashscreen:1.0.1")

    val composeBom = platform("androidx.compose:compose-bom:2024.09.02")
    implementation(composeBom)
    androidTestImplementation(composeBom)

    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.activity:activity-compose:1.8.2")
    implementation("androidx.compose.runtime:runtime-livedata:1.6.7")

    implementation("androidx.navigation:navigation-compose:2.7.7")

    implementation("com.google.code.gson:gson:2.10.1")

    implementation("com.google.ai.client.generativeai:generativeai:0.9.0")
    
    // ML Kit cho PII Redaction (L3 GĐ1)
    implementation("com.google.mlkit:entity-extraction:16.0.0-beta5")
    
    // Thay thế TensorFlow Lite độc lập bằng Google Play Services TFLite để tránh xung đột thư viện C++ (NdK)
    implementation("com.google.android.gms:play-services-tflite-java:16.1.0")
    
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.7.3")
    implementation("androidx.room:room-runtime:2.6.1")
    implementation("androidx.room:room-ktx:2.6.1")
    ksp("androidx.room:room-compiler:2.6.1")

    testImplementation("junit:junit:4.13.2")
    testImplementation("org.mockito:mockito-core:4.11.0")
    testImplementation("org.mockito:mockito-inline:4.11.0")
    testImplementation("org.mockito.kotlin:mockito-kotlin:4.1.0")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.7.3")
    androidTestImplementation("androidx.test.ext:junit:1.1.5")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.5.1")

    androidTestImplementation("androidx.compose.ui:ui-test-junit4")
    debugImplementation("androidx.compose.ui:ui-tooling")
    debugImplementation("androidx.compose.ui:ui-test-manifest")

    // Thư viện Vosk hỗ trợ Offline STT phân tích âm thanh trực tiếp (VoIP/Creator Mode)
    implementation("com.alphacephei:vosk-android:0.3.38") {
        exclude(group = "net.java.dev.jna", module = "jna")
    }
    implementation("net.java.dev.jna:jna:5.13.0@aar")
}
