# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Supabase
-keep class io.supabase.** { *; }

# Dio
-keep class dio.** { *; }

# Hive
-keep class hive.** { *; }
-keep class * implements hive.HiveObject { *; }

# Flutter Sound
-keep class com.dooboolab.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }

# Keep native methods
-keepclassmembers class * {
    native <methods>;
}

