import 'dart:io';

/// Parser for CocoaPods Podfile
class PodfileParser {
  /// Check if ULinkSDK pod is present
  static bool hasUlinkSdk(File podfile) {
    try {
      final content = podfile.readAsStringSync();
      return content.contains("pod 'ULinkSDK'") ||
          content.contains('pod "ULinkSDK"') ||
          content.contains('pod "ULinkSDK"');
    } catch (e) {
      return false;
    }
  }

  /// Extract SDK version if specified
  static String? extractSdkVersion(File podfile) {
    try {
      final content = podfile.readAsStringSync();
      // Match patterns like: pod 'ULinkSDK', '~> 1.0.0'
      // Escape quotes properly in raw string
      final versionPattern =
          RegExp(r"pod\s+['" "]ULinkSDK['" "],\s*['" "]([^'" "]+)['" "]");
      final versionMatch = versionPattern.firstMatch(content);
      return versionMatch?.group(1);
    } catch (e) {
      return null;
    }
  }

  /// Check if pod is commented out
  static bool isCommentedOut(File podfile) {
    try {
      final content = podfile.readAsStringSync();
      final lines = content.split('\n');
      for (final line in lines) {
        if (line.contains('ULinkSDK')) {
          return line.trim().startsWith('#');
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
