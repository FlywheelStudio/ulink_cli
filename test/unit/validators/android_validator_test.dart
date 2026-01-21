import 'dart:io';
import 'package:test/test.dart';
import 'package:ulink_cli/validators/android_validator.dart';
import 'package:ulink_cli/models/platform_config.dart';
import 'package:ulink_cli/models/verification_result.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('AndroidValidator', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await TestHelpers.createTempDir('android_validator_test_');
    });

    tearDown(() async {
      await TestHelpers.cleanupTempDir(tempDir);
    });

    group('validate', () {
      test('should return error when AndroidManifest.xml not found', () async {
        final results = AndroidValidator.validate(tempDir.path, null);

        expect(results.length, 1);
        expect(results[0].checkName, 'Android AndroidManifest.xml');
        expect(results[0].status, VerificationStatus.error);
        expect(results[0].message, contains('not found'));
      });

      test('should return success when AndroidManifest.xml found', () async {
        await TestHelpers.createAndroidProjectStructure(tempDir);

        final config = PlatformConfig(
          projectType: ProjectType.flutter,
          packageName: 'com.example.app',
          urlSchemes: ['myapp'],
        );

        final results = AndroidValidator.validate(tempDir.path, config);

        final manifestResult = results.firstWhere(
          (r) => r.checkName == 'Android AndroidManifest.xml',
        );
        expect(manifestResult.status, VerificationStatus.success);
        expect(manifestResult.message, contains('found'));
      });

      test('should return error when package name not found', () async {
        await TestHelpers.createAndroidProjectStructure(tempDir);

        final config = PlatformConfig(
          projectType: ProjectType.flutter,
          packageName: null, // Missing package name
          urlSchemes: ['myapp'],
        );

        final results = AndroidValidator.validate(tempDir.path, config);

        final packageResult = results.firstWhere(
          (r) => r.checkName == 'Android Package Name',
        );
        expect(packageResult.status, VerificationStatus.error);
        expect(packageResult.message, contains('not found'));
      });

      test('should return success when package name found', () async {
        await TestHelpers.createAndroidProjectStructure(
          tempDir,
          packageName: 'com.example.testapp',
        );

        final config = PlatformConfig(
          projectType: ProjectType.flutter,
          packageName: 'com.example.testapp',
          urlSchemes: ['myapp'],
        );

        final results = AndroidValidator.validate(tempDir.path, config);

        final packageResult = results.firstWhere(
          (r) => r.checkName == 'Android Package Name',
        );
        expect(packageResult.status, VerificationStatus.success);
        expect(packageResult.message, contains('com.example.testapp'));
      });

      test('should warn when no URL schemes found', () async {
        await TestHelpers.createAndroidProjectStructure(tempDir);

        final config = PlatformConfig(
          projectType: ProjectType.flutter,
          packageName: 'com.example.app',
          urlSchemes: [], // Empty URL schemes
        );

        final results = AndroidValidator.validate(tempDir.path, config);

        final schemeResult = results.firstWhere(
          (r) => r.checkName == 'Android URL Schemes',
        );
        expect(schemeResult.status, VerificationStatus.warning);
        expect(schemeResult.message, contains('No custom URL schemes'));
      });

      test('should return success when URL schemes found', () async {
        await TestHelpers.createAndroidProjectStructure(
          tempDir,
          urlSchemes: ['myapp', 'myapp-dev'],
        );

        final config = PlatformConfig(
          projectType: ProjectType.flutter,
          packageName: 'com.example.app',
          urlSchemes: ['myapp', 'myapp-dev'],
        );

        final results = AndroidValidator.validate(tempDir.path, config);

        final schemeResult = results.firstWhere(
          (r) => r.checkName == 'Android URL Schemes',
        );
        expect(schemeResult.status, VerificationStatus.success);
        expect(schemeResult.message, contains('myapp'));
      });

      test('should warn when no App Links found', () async {
        await TestHelpers.createAndroidProjectStructure(
          tempDir,
          urlSchemes: ['myapp'],
          appLinkHosts: [], // No App Links
        );

        final config = PlatformConfig(
          projectType: ProjectType.flutter,
          packageName: 'com.example.app',
          urlSchemes: ['myapp'],
          appLinkHosts: [],
        );

        final results = AndroidValidator.validate(tempDir.path, config);

        final appLinksResult = results.firstWhere(
          (r) => r.checkName == 'Android App Links',
        );
        expect(appLinksResult.status, VerificationStatus.warning);
        expect(appLinksResult.message, contains('No App Links'));
      });

      test('should return success when App Links found', () async {
        await TestHelpers.createAndroidProjectStructure(
          tempDir,
          urlSchemes: ['myapp'],
          appLinkHosts: ['example.com', 'api.example.com'],
        );

        final config = PlatformConfig(
          projectType: ProjectType.flutter,
          packageName: 'com.example.app',
          urlSchemes: ['myapp'],
          appLinkHosts: ['example.com', 'api.example.com'],
        );

        final results = AndroidValidator.validate(tempDir.path, config);

        final appLinksResult = results.firstWhere(
          (r) => r.checkName == 'Android App Links',
        );
        expect(appLinksResult.status, VerificationStatus.success);
        expect(appLinksResult.message, contains('example.com'));
      });

      test('should handle null platform config', () async {
        await TestHelpers.createAndroidProjectStructure(tempDir);

        final results = AndroidValidator.validate(tempDir.path, null);

        // Should only check for AndroidManifest.xml
        expect(results.length, 1);
        expect(results[0].checkName, 'Android AndroidManifest.xml');
        expect(results[0].status, VerificationStatus.success);
      });

      test('should validate pure Android project', () async {
        // Create Android project structure (not Flutter)
        await TestHelpers.createFile(
          tempDir,
          'app/src/main/AndroidManifest.xml',
          '''<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.example.android">
    <application android:label="Android App">
        <activity android:name=".MainActivity">
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="androidapp" />
            </intent-filter>
        </activity>
    </application>
</manifest>''',
        );

        final config = PlatformConfig(
          projectType: ProjectType.android,
          packageName: 'com.example.android',
          urlSchemes: ['androidapp'],
        );

        final results = AndroidValidator.validate(tempDir.path, config);

        final manifestResult = results.firstWhere(
          (r) => r.checkName == 'Android AndroidManifest.xml',
        );
        expect(manifestResult.status, VerificationStatus.success);
      });

      test('should return all validation results', () async {
        await TestHelpers.createAndroidProjectStructure(
          tempDir,
          packageName: 'com.example.app',
          urlSchemes: ['myapp'],
          appLinkHosts: ['example.com'],
        );

        final config = PlatformConfig(
          projectType: ProjectType.flutter,
          packageName: 'com.example.app',
          urlSchemes: ['myapp'],
          appLinkHosts: ['example.com'],
        );

        final results = AndroidValidator.validate(tempDir.path, config);

        // Should have checks for: manifest, package name, URL schemes, App Links
        expect(results.length, 4);
        expect(
          results.every((r) => r.status == VerificationStatus.success),
          isTrue,
        );
      });
    });
  });
}
