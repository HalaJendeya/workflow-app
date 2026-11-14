# Release builds are shrunk by R8 (the Flutter Gradle plugin enables it and
# adds this file when it exists).
#
# flutter_webrtc ships its own rules for org.webrtc. The LiveKit plugin and
# its native noise filter, and the audio router used by flutter_webrtc, are
# reached from native code by name: keep them so a release build behaves
# like a debug build in a call.
-keep class io.livekit.** { *; }
-keep class com.twilio.audioswitch.** { *; }
-dontwarn io.livekit.**
