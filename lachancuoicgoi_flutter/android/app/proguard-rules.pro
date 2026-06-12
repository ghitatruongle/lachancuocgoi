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

# ─── Vosk (offline STT) ────────────────────────────────────────────────────────
-keep class org.vosk.** { *; }
-keep class com.alphacephei.** { *; }
-dontwarn org.vosk.**

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

# ─── Flutter deferred components (Play Core — not used, suppress R8 warnings) ───
-dontwarn com.google.android.play.core.**
