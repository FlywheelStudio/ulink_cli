/// Local platform configuration extracted from project files
class PlatformConfig {
  final ProjectType projectType;
  final String? bundleIdentifier; // iOS
  final String? packageName; // Android
  final List<String>
      urlSchemes; // Custom URL schemes (combined for Flutter, platform-specific for iOS/Android)
  final List<String> iosUrlSchemes; // iOS-specific URL schemes
  final List<String> androidUrlSchemes; // Android-specific URL schemes
  final List<String> associatedDomains; // iOS universal links
  final List<String> appLinkHosts; // Android app links
  final List<String> sha256Fingerprints; // Android signing fingerprints
  final String? teamId; // iOS team ID

  PlatformConfig({
    required this.projectType,
    this.bundleIdentifier,
    this.packageName,
    this.urlSchemes = const [],
    this.iosUrlSchemes = const [],
    this.androidUrlSchemes = const [],
    this.associatedDomains = const [],
    this.appLinkHosts = const [],
    this.sha256Fingerprints = const [],
    this.teamId,
  });
}

/// Project type enumeration
enum ProjectType { flutter, ios, android, unknown }
