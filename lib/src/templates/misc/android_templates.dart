/// Generates Android project support files (R8 / ProGuard rules).
class AndroidTemplates {
  AndroidTemplates._();

  /// Returns the `android/app/proguard-rules.pro` keep rules.
  ///
  /// Also rendered into `docs/SECURITY_BEFORE_DEPLOYMENT.md`, so the doc and
  /// the generated file are always the same rules.
  static String proguardRules() => r'''
# ProGuard / R8 keep rules.
#
# These do nothing until R8 is turned on for the release build type
# (minifyEnabled / shrinkResources + proguardFiles) — see
# docs/SECURITY_BEFORE_DEPLOYMENT.md for that block and the rest of the
# pre-release checklist.

##──── Flutter engine ────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

##──── Dart / Flutter generated code ─────────────────────────────────────────
# Keep classes referenced via reflection or generated JSON serialisers
-keep class * extends io.flutter.plugin.common.PluginRegistry { *; }

##──── Google Play Core / In-App Updates & Integrity ────────────────────────
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

##──── Firebase ───────────────────────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

##──── OkHttp / Dio (networking) ─────────────────────────────────────────────
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

##──── Kotlin coroutines ──────────────────────────────────────────────────────
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory { *; }
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler { *; }
-dontwarn kotlinx.coroutines.**

##──── Serialisation — keep model classes from being stripped ────────────────
# If you use json_serializable or freezed, keep your data package:
# -keep class com.yourcompany.yourapp.data.models.** { *; }

##──── Prevent stripping enums ───────────────────────────────────────────────
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

##──── Native methods ─────────────────────────────────────────────────────────
-keepclasseswithmembernames class * {
    native <methods>;
}

##──── Debugging: preserve line numbers in stack traces ──────────────────────
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
''';
}
