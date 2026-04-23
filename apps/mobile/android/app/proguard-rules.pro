# FitCore ProGuard / R8 rules
# ── Flutter ───────────────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ── Flutter Play Store deferred components (not used by FitCore) ──────────────
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task

# ── ML Kit text recognition (non-Latin script stubs) ─────────────────────────
# These script-specific model classes are optional at runtime (only Latin is
# bundled). R8 sees references from the plugin's dispatch table and fails
# unless we suppress the warnings for absent classes.
-dontwarn com.google.firebase.iid.FirebaseInstanceId
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions

# ── Dio (HTTP client) ─────────────────────────────────────────────────────────
# Dio uses Dart mirrors / reflection for request/response model serialisation.
# Keep all classes referenced via generics at runtime.
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# ── Riverpod ──────────────────────────────────────────────────────────────────
# Riverpod generates code at compile time so there are no runtime reflective
# lookups; the rules below guard against R8 stripping generated provider
# registrations referenced only from generated code.
-keep class dev.rrousselgit.riverpod.** { *; }
-dontwarn dev.rrousselgit.riverpod.**

# ── Drift (SQLite ORM) ────────────────────────────────────────────────────────
# Drift's generated DAOs and table classes must survive shrinking.
-keep class com.simolus.** { *; }
-dontwarn com.simolus.**
# SQLite JDBC driver (used by drift_flutter under the hood on Android)
-keep class org.sqlite.** { *; }
-dontwarn org.sqlite.**

# ── Sentry Flutter ────────────────────────────────────────────────────────────
-keep class io.sentry.** { *; }
-dontwarn io.sentry.**
-keep class io.sentry.android.** { *; }
-dontwarn io.sentry.android.**

# ── flutter_local_notifications (Gson TypeToken) ─────────────────────────────
# R8 strips generic signatures from Gson's TypeToken, crashing the plugin's
# scheduled-notification cache on startup. Keep the class and all subclasses.
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keepattributes Signature
-keepattributes *Annotation*

# ── Firebase / FCM ────────────────────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# ── Kotlin coroutines ─────────────────────────────────────────────────────────
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-dontwarn kotlinx.coroutines.**

# ── Preserve Dart entrypoint ──────────────────────────────────────────────────
-keep class **.GeneratedPluginRegistrant { *; }
