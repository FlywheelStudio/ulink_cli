import 'dart:io';
import 'package:test/test.dart';
import 'package:ulink_cli/validators/ios_validator.dart';
import 'package:ulink_cli/models/platform_config.dart';
import 'package:ulink_cli/models/verification_result.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('IosValidator', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await TestHelpers.createTempDir('ios_validator_test_');
    });

    tearDown(() async {
      await TestHelpers.cleanupTempDir(tempDir);
    });

    group('validate', () {
      test('should return error when Info.plist not found', () async {
        final results = IosValidator.validate(tempDir.path, null);

        expect(results.length, 1);
        expect(results[0].checkName, 'iOS Info.plist');
        expect(results[0].status, VerificationStatus.error);
        expect(results[0].message, contains('not found'));
      });

      test('should return success when Info.plist found', () async {
        await TestHelpers.createIosProjectStructure(tempDir);

        final config = PlatformConfig(
          projectType: ProjectType.flutter,
          bundleIdentifier: 'com.example.app',
          urlSchemes: ['myapp'],
        );

        final results = IosValidator.validate(tempDir.path, config);

        final plistResult = results.firstWhere(
          (r) => r.checkName == 'iOS Info.plist',
        );
        expect(plistResult.status, VerificationStatus.success);
        expect(plistResult.message, contains('found'));
      });

      test('should warn when no URL schemes found', () async {
        await TestHelpers.createIosProjectStructure(tempDir);

        final config = PlatformConfig(
          projectType: ProjectType.flutter,
          bundleIdentifier: 'com.example.app',
          urlSchemes: [], // Empty URL schemes
        );

        final results = IosValidator.validate(tempDir.path, config);

        final schemeResult = results.firstWhere(
          (r) => r.checkName == 'iOS URL Schemes',
        );
        expect(schemeResult.status, VerificationStatus.warning);
        expect(schemeResult.message, contains('No URL schemes found'));
      });

      test('should return success when URL schemes found', () async {
        await TestHelpers.createIosProjectStructure(
          tempDir,
          urlSchemes: ['myapp', 'myapp-dev'],
        );

        final config = PlatformConfig(
          projectType: ProjectType.flutter,
          bundleIdentifier: 'com.example.app',
          urlSchemes: ['myapp', 'myapp-dev'],
        );

        final results = IosValidator.validate(tempDir.path, config);

        final schemeResult = results.firstWhere(
          (r) => r.checkName == 'iOS URL Schemes',
        );
        expect(schemeResult.status, VerificationStatus.success);
        expect(schemeResult.message, contains('myapp'));
      });

      test('should return error when bundle identifier not found', () async {
        await TestHelpers.createIosProjectStructure(tempDir);

        final config = PlatformConfig(
          projectType: ProjectType.flutter,
          bundleIdentifier: null, // Missing bundle ID
          urlSchemes: ['myapp'],
        );

        final results = IosValidator.validate(tempDir.path, config);

        final bundleResult = results.firstWhere(
          (r) => r.checkName == 'iOS Bundle Identifier',
        );
        expect(bundleResult.status, VerificationStatus.error);
        expect(bundleResult.message, contains('not found'));
      });

      test('should warn when entitlements file not found', () async {
        await TestHelpers.createIosProjectStructure(tempDir);

        final config = PlatformConfig(
          projectType: ProjectType.flutter,
          bundleIdentifier: 'com.example.app',
          urlSchemes: ['myapp'],
        );

        final results = IosValidator.validate(tempDir.path, config);

        final entitlementsResult = results.firstWhere(
          (r) => r.checkName == 'iOS Entitlements',
        );
        expect(entitlementsResult.status, VerificationStatus.warning);
        expect(entitlementsResult.message, contains('not found'));
      });

      test('should return success when associated domains in config', () async {
        await TestHelpers.createIosProjectStructure(
          tempDir,
          associatedDomains: ['example.com'],
        );

        final config = PlatformConfig(
          projectType: ProjectType.flutter,
          bundleIdentifier: 'com.example.app',
          urlSchemes: ['myapp'],
          associatedDomains: ['example.com'],
        );

        final results = IosValidator.validate(tempDir.path, config);

        // When platformConfig has associatedDomains, validator uses those directly
        final domainsResult = results.firstWhere(
          (r) => r.checkName == 'iOS Associated Domains',
        );
        expect(domainsResult.status, VerificationStatus.success);
        expect(domainsResult.message, contains('example.com'));
      });

      test('should return error when no associated domains in entitlements', () async {
        // Create entitlements without associated domains
        await TestHelpers.createFile(
          tempDir,
          'ios/Runner/Runner.entitlements',
          '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.example.app</string>
    </array>
</dict>
</plist>''',
        );

        // Also need Info.plist for the validator to proceed
        await TestHelpers.createIosProjectStructure(tempDir);

        final config = PlatformConfig(
          projectType: ProjectType.flutter,
          bundleIdentifier: 'com.example.app',
          urlSchemes: ['myapp'],
        );

        final results = IosValidator.validate(tempDir.path, config);

        final domainsResult = results.firstWhere(
          (r) => r.checkName == 'iOS Associated Domains',
        );
        expect(domainsResult.status, VerificationStatus.error);
        expect(domainsResult.message, contains('No associated domains'));
      });

      test('should return success when associated domains found', () async {
        await TestHelpers.createIosProjectStructure(
          tempDir,
          associatedDomains: ['example.com', 'api.example.com'],
        );

        final config = PlatformConfig(
          projectType: ProjectType.flutter,
          bundleIdentifier: 'com.example.app',
          urlSchemes: ['myapp'],
          associatedDomains: ['example.com', 'api.example.com'],
        );

        final results = IosValidator.validate(tempDir.path, config);

        final domainsResult = results.firstWhere(
          (r) => r.checkName == 'iOS Associated Domains',
        );
        expect(domainsResult.status, VerificationStatus.success);
        expect(domainsResult.message, contains('example.com'));
      });

      test('should handle null platform config', () async {
        await TestHelpers.createIosProjectStructure(tempDir);

        final results = IosValidator.validate(tempDir.path, null);

        // Should still check for Info.plist and entitlements
        expect(results.any((r) => r.checkName == 'iOS Info.plist'), isTrue);
      });

      test('should use ios project type when platform config project type is ios', () async {
        // Create iOS project structure (not Flutter)
        await TestHelpers.createFile(
          tempDir,
          'MyApp/Info.plist',
          '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.example.app</string>
</dict>
</plist>''',
        );

        final config = PlatformConfig(
          projectType: ProjectType.ios,
          bundleIdentifier: 'com.example.app',
          urlSchemes: [],
        );

        final results = IosValidator.validate(tempDir.path, config);

        final plistResult = results.firstWhere(
          (r) => r.checkName == 'iOS Info.plist',
        );
        expect(plistResult.status, VerificationStatus.success);
      });
    });
  });
}
