# Changelog

## 0.1.0 (Initial Release)

### Features
- Project type detection (Flutter, iOS, Android)
- SDK package installation validation
- Local configuration file parsing (Info.plist, AndroidManifest.xml, entitlements)
- ULink API integration for project configuration
- Cross-reference validation between local and ULink configs
- Well-known file verification (AASA, Asset Links JSON)
- Runtime tests for iOS and Android
- Comprehensive verification report generation
- Interactive fix mode (basic implementation)

### Supported Platforms
- Flutter projects
- iOS projects (Xcode)
- Android projects (Gradle)

### Requirements
- Dart SDK 3.6.2+
- For iOS testing: Xcode with xcrun simctl
- For Android testing: Android SDK with adb in PATH
