# SACDIA R8/ProGuard rules for release builds.
# The Flutter Gradle plugin already injects keep rules for the Flutter engine
# and every plugin ships its own consumer rules; only project-specific
# additions belong here.

# Play Core is referenced by Flutter's deferred-components support but is not
# a dependency of this app. R8 fails the build on the missing classes without
# these -dontwarn directives.
-dontwarn com.google.android.play.core.**

# Keep crash reports readable: preserve source file names and line numbers
# (Sentry symbolication relies on them).
-keepattributes SourceFile,LineNumberTable

# flutter_secure_storage uses Tink for AES encryption; Tink references
# optional protobuf/api classes that are absent at runtime.
-dontwarn com.google.errorprone.annotations.**
-dontwarn javax.annotation.**
