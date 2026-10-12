# Proguard rules for Vosk JNA native bindings
-keep class com.sun.jna.* { *; }
-keepclassmembers class * extends com.sun.jna.* { public *; }

# JNA desktop AWT references not present on Android
-dontwarn java.awt.**
