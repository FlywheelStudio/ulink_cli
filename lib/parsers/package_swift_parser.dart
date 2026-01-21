import 'dart:io';

/// Parser for Swift Package Manager Package.swift
class PackageSwiftParser {
  /// Check if ULinkSDK package is present
  static bool hasUlinkSdk(File packageSwift) {
    try {
      final content = packageSwift.readAsStringSync();
      return content.contains('ULinkSDK') ||
          content.contains('ios_ulink_sdk') ||
          (content.contains('github.com') && content.contains('ulink'));
    } catch (e) {
      return false;
    }
  }

  /// Extract package URL if present
  static String? extractPackageUrl(File packageSwift) {
    try {
      final content = packageSwift.readAsStringSync();
      // Match .package(url: "...", ...) patterns
      final urlPattern = RegExp(r'\.package\(url:\s*["' ']([^"' ']+)["' ']');
      final urlMatch = urlPattern.firstMatch(content);
      if (urlMatch != null) {
        final url = urlMatch.group(1);
        if (url != null &&
            (url.contains('ulink') || url.contains('ULinkSDK'))) {
          return url;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
