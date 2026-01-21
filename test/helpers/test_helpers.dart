import 'dart:io';
import 'package:path/path.dart' as path;

/// Test helper utilities for creating temporary test environments
class TestHelpers {
  /// Create a temporary directory for testing
  static Future<Directory> createTempDir([String? prefix]) async {
    final tempDir = await Directory.systemTemp.createTemp(prefix ?? 'ulink_test_');
    return tempDir;
  }

  /// Clean up a temporary directory
  static Future<void> cleanupTempDir(Directory dir) async {
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  /// Create a file with content in the given directory
  static Future<File> createFile(
    Directory dir,
    String relativePath,
    String content,
  ) async {
    final file = File(path.join(dir.path, relativePath));
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
    return file;
  }

  /// Create an iOS project structure for testing
  static Future<Directory> createIosProjectStructure(
    Directory baseDir, {
    String bundleId = 'com.example.app',
    List<String> urlSchemes = const [],
    String? teamId,
    List<String> associatedDomains = const [],
  }) async {
    // Create Info.plist
    final urlSchemesXml = urlSchemes.isEmpty
        ? ''
        : '''
    <key>CFBundleURLTypes</key>
    <array>
      <dict>
        <key>CFBundleURLSchemes</key>
        <array>
${urlSchemes.map((s) => '          <string>$s</string>').join('\n')}
        </array>
      </dict>
    </array>''';

    final infoPlist = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>$bundleId</string>
$urlSchemesXml
</dict>
</plist>''';

    await createFile(baseDir, 'ios/Runner/Info.plist', infoPlist);

    // Create entitlements if associated domains provided
    if (associatedDomains.isNotEmpty) {
      final entitlements = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.associated-domains</key>
    <array>
${associatedDomains.map((d) => '        <string>applinks:$d</string>').join('\n')}
    </array>
</dict>
</plist>''';
      await createFile(baseDir, 'ios/Runner/Runner.entitlements', entitlements);
    }

    // Create project.pbxproj with team ID if provided
    if (teamId != null) {
      final pbxproj = '// !\$*UTF8*\$!\n'
          '{\n'
          '  buildSettings = {\n'
          '    DEVELOPMENT_TEAM = $teamId;\n'
          '    PRODUCT_BUNDLE_IDENTIFIER = $bundleId;\n'
          '  };\n'
          '}';
      await createFile(
          baseDir, 'ios/Runner.xcodeproj/project.pbxproj', pbxproj);
    }

    return baseDir;
  }

  /// Create an Android project structure for testing
  static Future<Directory> createAndroidProjectStructure(
    Directory baseDir, {
    String packageName = 'com.example.app',
    List<String> urlSchemes = const [],
    List<String> appLinkHosts = const [],
    bool useNamespace = false,
  }) async {
    // Build intent filters
    final intentFilters = StringBuffer();

    // Add URL scheme intent filters
    for (final scheme in urlSchemes) {
      intentFilters.writeln('''
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="$scheme" />
            </intent-filter>''');
    }

    // Add App Link intent filters
    for (final host in appLinkHosts) {
      intentFilters.writeln('''
            <intent-filter android:autoVerify="true">
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="https" android:host="$host" />
            </intent-filter>''');
    }

    final packageAttr = useNamespace ? '' : ' package="$packageName"';
    final manifest = '''<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"$packageAttr>
    <application android:label="Test App">
        <activity android:name=".MainActivity">
$intentFilters
        </activity>
    </application>
</manifest>''';

    await createFile(baseDir, 'android/app/src/main/AndroidManifest.xml', manifest);

    // Create build.gradle with namespace if using namespace
    if (useNamespace) {
      final buildGradle = '''android {
    namespace "$packageName"
    compileSdk 34
}''';
      await createFile(baseDir, 'android/app/build.gradle', buildGradle);
    }

    return baseDir;
  }

  /// Create a Flutter project structure for testing
  static Future<Directory> createFlutterProjectStructure(
    Directory baseDir, {
    String name = 'test_app',
    String? iosBundleId,
    String? androidPackageName,
    List<String> iosUrlSchemes = const [],
    List<String> androidUrlSchemes = const [],
  }) async {
    // Create pubspec.yaml
    final pubspec = '''name: $name
description: A test Flutter project
version: 1.0.0

environment:
  sdk: ^3.0.0
  flutter: ">=3.0.0"

dependencies:
  flutter:
    sdk: flutter
''';
    await createFile(baseDir, 'pubspec.yaml', pubspec);

    // Create iOS structure
    await createIosProjectStructure(
      baseDir,
      bundleId: iosBundleId ?? 'com.example.$name',
      urlSchemes: iosUrlSchemes,
    );

    // Create Android structure
    await createAndroidProjectStructure(
      baseDir,
      packageName: androidPackageName ?? 'com.example.$name',
      urlSchemes: androidUrlSchemes,
    );

    return baseDir;
  }
}
