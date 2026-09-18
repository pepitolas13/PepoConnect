# PepoConnect R8/ProGuard rules for the release build.
# The Flutter Gradle plugin already adds flutter_proguard_rules.pro (keeps every
# FlutterPlugin implementation, -dontwarn io.flutter.plugin.** / android.**).
# Plugins that ship consumer rules (mobile_scanner, Glide, Gson) are merged
# automatically; the rules below are the explicit safety net.

# --- Flutter embedding ------------------------------------------------------
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**
# Deferred components (Play Core) are referenced by the engine but not used.
-dontwarn com.google.android.play.core.**

# --- PepoConnect natives: MethodChannel bridge, foreground service, receivers --
-keep class org.pepoconnect.app.** { *; }

# --- photo_manager (+ Glide, used for thumbnails) ------------------------------
-keep class com.fluttercandies.photo_manager.** { *; }
-keep public class * implements com.bumptech.glide.module.GlideModule
-keep class * extends com.bumptech.glide.module.AppGlideModule { <init>(...); }
-keep public enum com.bumptech.glide.load.ImageHeaderParser$** { *; }
-dontwarn com.bumptech.glide.load.resource.bitmap.VideoDecoder

# --- mobile_scanner (bundled ML Kit barcode scanning) --------------------------
-keep class dev.steenbakker.mobile_scanner.** { *; }
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode.** { *; }
-keep class com.google.android.libraries.barhopper.** { *; }
-keep class com.google.photos.** { *; }
-keepclassmembers class * extends java.lang.Enum {
    <fields>;
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# --- flutter_local_notifications (Gson-serialised models) ----------------------
-keepattributes Signature, *Annotation*, EnclosingMethod, InnerClasses
-dontwarn sun.misc.**
-keep class com.dexterous.** { *; }
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken

# --- share_handler (Pigeon-generated messages) ---------------------------------
-keep class com.shoutsocial.share_handler.** { *; }

# --- Kotlin metadata / coroutines used by several plugins ----------------------
-keep class kotlin.Metadata { *; }
-dontwarn kotlinx.coroutines.**
