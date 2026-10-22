# Flutter Engine & Framework
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Hive NoSQL Local Database & Type Adapters
-keep class io.hive.** { *; }
-keep class * implements io.hive.** { *; }
-dontwarn io.hive.**

# Keep reflection and serialization intact
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# HTTP & SSL Networking
-dontwarn java.awt.**
-dontwarn sun.misc.**
-dontwarn okio.**
