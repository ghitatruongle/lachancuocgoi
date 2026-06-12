# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.
#
# For more details, see
#   http://developer.android.com/guide/developing/tools/proguard.html

# If your project uses WebView with JS, uncomment the following
# and specify the fully qualified class name to the JavaScript interface
# class:
#-keepclassmembers class fqcn.of.javascript.interface.for.webview {
#   public *;
#}

# Uncomment this to preserve the line number information for
# debugging stack traces.
#-keepattributes SourceFile,LineNumberTable

# If you keep the line number information, uncomment this to
# hide the original source file name.
#-renamesourcefileattribute SourceFile

# TFLite
-keep class org.tensorflow.** { *; }
-keep class com.google.android.gms.tflite.** { *; }
-keep class com.google.android.gms.internal.tflite.** { *; }

# Gson
-keepattributes Signature
-keepattributes *Annotation*
-keep class sun.misc.Unsafe { *; }
-keep class com.google.gson.** { *; }
-keep class com.google.gson.reflect.** { *; }
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken

# Room
-keep class androidx.room.** { *; }
# Models for Gson and DB
-keep class com.example.lachancuocgoi.data.** { *; }
-keep class com.example.lachancuocgoi.Analysis.L3.core.** { *; }
-keep class com.example.lachancuocgoi.Analysis.**Config* { *; }
-keep class com.example.lachancuocgoi.Analysis.**Model* { *; }
-keep class com.example.lachancuocgoi.Analysis.**DTO* { *; }
-keep class com.example.lachancuocgoi.ui.SimulationPage.**Data* { *; }
-keep class com.example.lachancuocgoi.Analysis.L2.GDetection.** { *; }