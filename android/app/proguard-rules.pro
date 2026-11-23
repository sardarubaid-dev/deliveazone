# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Your Model Classes - Keep them from being obfuscated so JSON mapping works
-keep class com.susolz.deliveazone_driver_app.models.** { *; }

# Handle parcelable
-keep class * implements android.os.Parcelable {
  public static final android.os.Parcelable$Creator *;
}

# Fix R8 missing class errors for Play Core (common in Flutter release builds)
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# Workmanager ProGuard Rules
-keep class com.google.common.util.concurrent.ListenableFuture { *; }
-dontwarn androidx.work.impl.background.systemalarm.SystemAlarmService

# General Optimization
-dontoptimize
-dontobfuscate
-keepattributes Signature,Exceptions,*Annotation*
