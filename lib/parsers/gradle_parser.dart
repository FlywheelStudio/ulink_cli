import 'dart:io';

/// Parser for Gradle build files (build.gradle and build.gradle.kts)
class GradleParser {
  /// Extract package name from build.gradle or build.gradle.kts
  static String? extractPackageName(File gradleFile) {
    try {
      final content = gradleFile.readAsStringSync();

      // Try to find namespace (newer Gradle format)
      final namespacePattern =
          RegExp(r'namespace\s*[=:]\s*["' ']([^"' ']+)["' ']');
      final namespaceMatch = namespacePattern.firstMatch(content);
      if (namespaceMatch != null) {
        return namespaceMatch.group(1);
      }

      // Try to find package in android block (older format)
      // Using (?s) for dotAll and (?m) for multiline
      final androidBlockPattern = RegExp(
        r'(?s)android\s*\{[^}]*package\s*[=:]\s*["' ']([^"' ']+)["' ']',
      );
      final androidBlockMatch = androidBlockPattern.firstMatch(content);
      if (androidBlockMatch != null) {
        return androidBlockMatch.group(1);
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Check if ULink SDK dependency exists
  static bool hasUlinkSdk(File gradleFile) {
    try {
      final content = gradleFile.readAsStringSync();
      return content.contains('ly.ulink:ulink-sdk') ||
          (content.contains('com.github') &&
              content.contains('android-ulink-sdk'));
    } catch (e) {
      return false;
    }
  }

  /// Extract SDK version if present
  static String? extractSdkVersion(File gradleFile) {
    try {
      final content = gradleFile.readAsStringSync();
      final versionPattern = RegExp(r'ly\.ulink:ulink-sdk:([\d.]+)');
      final versionMatch = versionPattern.firstMatch(content);
      return versionMatch?.group(1);
    } catch (e) {
      return null;
    }
  }
}
