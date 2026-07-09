# ─── Flutter ────────────────────────────────────────────────────────────────────
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }

# ─── TFLite ─────────────────────────────────────────────────────────────────────
-keep class org.tensorflow.** { *; }
-keep class org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.**
# BUG-PROGUARD fix: Keep TFLite reflection-based classes and native methods
-keepclassmembers class * {
    native <methods>;
}
-keep class org.tensorflow.lite.support.** { *; }

# ─── Vosk (offline STT) ────────────────────────────────────────────────────────
-keep class org.vosk.** { *; }
-keep class com.alphacephei.** { *; }
-dontwarn org.vosk.**
# BUG-PROGUARD fix: Keep JNI methods for Vosk native library
-keepclasseswithmembernames,includedescriptorclasses class * {
    native <methods>;
}

# ─── Google Generative AI (Gemini SDK) ──────────────────────────────────────────
-keep class com.google.ai.** { *; }
-dontwarn com.google.ai.**

# ─── sqflite ────────────────────────────────────────────────────────────────────
-keep class com.tekartik.sqflite.** { *; }
-dontwarn com.tekartik.sqflite.**

# ─── General ────────────────────────────────────────────────────────────────────
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# BUG-PROGUARD fix: Keep MethodChannel/EventChannel argument serialization
-keepclassmembers class * {
    @io.flutter.embedding.engine.dart.DartMessenger.DartMessageHandler *;
}
-keep class io.flutter.plugin.common.** { *; }

# ─── Flutter deferred components (Play Core — not used, suppress R8 warnings) ───
-dontwarn com.google.android.play.core.**

# ─── JNA (Java Native Access) ────────────────────────────────────────────────────
-keep class com.sun.jna.** { *; }
-keepclassmembers class * extends com.sun.jna.** { *; }
-dontwarn com.sun.jna.**

# ─── Wave 5 Hardening: Keep security-critical classes ──────────────────────────
# Wave 5 fix: ApiKeyObfuscator must keep its XOR encoding methods
# and field names for runtime deobfuscation to work after R8 minification.
-keep class com.lachancuocgoi.lachancuocgoi_flutter.analysis.l3.core.ApiKeyObfuscator { *; }

# EnvironmentApiKeyProvider must keep its dart-define + asset loading logic.
# Without -keep, R8 may rename `ensureLoaded()` and break env.json loading.
-keep class com.lachancuocgoi.lachancuocgoi_flutter.analysis.l3.core.EnvironmentApiKeyProvider { *; }

# PermissionHelpers (Wave 2 extract) is called via reflection from Riverpod providers.
-keep class com.lachancuocgoi.lachancuocgoi_flutter.helpers.PermissionHelpers { *; }

# ─── Wave 5 Hardening: General security ─────────────────────────────────────────
# Enable aggressive optimization (R8 full mode requires AGP 7.0+)
-optimizationpasses 5

# Keep enum values for switch statements
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep Parcelable creators (Android system requirement)
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}

# Keep Serializable magic fields
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}