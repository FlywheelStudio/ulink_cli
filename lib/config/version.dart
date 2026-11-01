/// ULink CLI version information
class ULinkVersion {
  /// Current version of the CLI tool
  static const String version = '1.4.6';

  /// Build number (incremented with each build)
  static const String buildNumber = '46';

  /// Build date (ISO 8601 format), set at compile time with
  /// `-DBUILD_DATE=YYYY-MM-DD` by build.sh and the release workflow.
  static const String buildDate =
      String.fromEnvironment('BUILD_DATE', defaultValue: 'unknown');

  /// Get full version string
  static String get fullVersion => '$version+$buildNumber';

  /// Get version info as a formatted string
  static String get versionInfo => '''
Ulinkly CLI Version: $version
Build Number: $buildNumber
Build Date: $buildDate
''';

  /// Get short version string for display
  static String get shortVersion => 'v$version (build $buildNumber)';
}
