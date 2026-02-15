import 'dart:io';
import 'package:test/test.dart';
import 'package:ulink_cli/validators/sdk_package_validator.dart';
import 'package:ulink_cli/models/platform_config.dart';
import 'package:ulink_cli/models/verification_result.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('SdkPackageValidator', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await TestHelpers.createTempDir('sdk_validator_test_');
    });

    tearDown(() async {
      await TestHelpers.cleanupTempDir(tempDir);
    });

    group('iOS - CocoaPods only', () {
      test('should return success when ULinkSDK in Podfile and Podfile.lock', () async {
        await TestHelpers.createFile(
          tempDir,
          'Podfile',
          "pod 'ULinkSDK', '~> 1.0.0'",
        );
        await TestHelpers.createFile(
          tempDir,
          'Podfile.lock',
          'PODS:\n  - ULinkSDK (1.0.0)',
        );

        final results = SdkPackageValidator.validate(tempDir.path, ProjectType.ios);

        expect(results.length, 1);
        expect(results[0].checkName, 'SDK Package - iOS (CocoaPods)');
        expect(results[0].status, VerificationStatus.success);
        expect(results[0].message, contains('Podfile and Podfile.lock'));
      });

      test('should return warning when ULinkSDK in Podfile but not Podfile.lock', () async {
        await TestHelpers.createFile(
          tempDir,
          'Podfile',
          "pod 'ULinkSDK', '~> 1.0.0'",
        );
        await TestHelpers.createFile(
          tempDir,
          'Podfile.lock',
          'PODS:\n  - SomeOtherPod (1.0.0)',
        );

        final results = SdkPackageValidator.validate(tempDir.path, ProjectType.ios);

        expect(results.length, 1);
        expect(results[0].checkName, 'SDK Package - iOS (CocoaPods)');
        expect(results[0].status, VerificationStatus.warning);
        expect(results[0].fixSuggestion, contains('pod install'));
      });

      test('should return warning when Podfile.lock missing', () async {
        await TestHelpers.createFile(
          tempDir,
          'Podfile',
          "pod 'ULinkSDK', '~> 1.0.0'",
        );

        final results = SdkPackageValidator.validate(tempDir.path, ProjectType.ios);

        expect(results.length, 1);
        expect(results[0].checkName, 'SDK Package - iOS (CocoaPods)');
        expect(results[0].status, VerificationStatus.warning);
        expect(results[0].fixSuggestion, contains('pod install'));
      });
    });

    group('iOS - SPM only', () {
      test('should return success when ULinkSDK in Package.swift', () async {
        await TestHelpers.createFile(
          tempDir,
          'Package.swift',
          '''
// swift-tools-version:5.5
import PackageDescription
let package = Package(
    name: "MyApp",
    dependencies: [
        .package(url: "https://github.com/nickmohnblatt/ios_ulink_sdk", from: "1.0.0"),
    ]
)
''',
        );

        final results = SdkPackageValidator.validate(tempDir.path, ProjectType.ios);

        expect(results.length, 1);
        expect(results[0].checkName, 'SDK Package - iOS (SPM)');
        expect(results[0].status, VerificationStatus.success);
        expect(results[0].message, contains('Package.swift'));
      });

      test('should return success when ULinkSDK name in Package.swift', () async {
        await TestHelpers.createFile(
          tempDir,
          'Package.swift',
          '''
import PackageDescription
let package = Package(
    dependencies: [
        .package(name: "ULinkSDK", url: "https://example.com/sdk", from: "1.0.0"),
    ]
)
''',
        );

        final results = SdkPackageValidator.validate(tempDir.path, ProjectType.ios);

        expect(results.length, 1);
        expect(results[0].checkName, 'SDK Package - iOS (SPM)');
        expect(results[0].status, VerificationStatus.success);
      });
    });

    group('iOS - both CocoaPods and SPM', () {
      test('should report both when SDK found in Podfile and Package.swift', () async {
        // Create Podfile with ULinkSDK
        await TestHelpers.createFile(
          tempDir,
          'Podfile',
          "pod 'ULinkSDK', '~> 1.0.0'",
        );
        await TestHelpers.createFile(
          tempDir,
          'Podfile.lock',
          'PODS:\n  - ULinkSDK (1.0.0)',
        );
        // Create Package.swift with ULinkSDK
        await TestHelpers.createFile(
          tempDir,
          'Package.swift',
          '''
import PackageDescription
let package = Package(
    dependencies: [
        .package(name: "ULinkSDK", url: "https://example.com/sdk", from: "1.0.0"),
    ]
)
''',
        );

        final results = SdkPackageValidator.validate(tempDir.path, ProjectType.ios);

        // Should have results for BOTH CocoaPods and SPM
        expect(results.length, 2);
        final podResult = results.firstWhere(
          (r) => r.checkName == 'SDK Package - iOS (CocoaPods)',
        );
        final spmResult = results.firstWhere(
          (r) => r.checkName == 'SDK Package - iOS (SPM)',
        );
        expect(podResult.status, VerificationStatus.success);
        expect(spmResult.status, VerificationStatus.success);
      });

      test('should check SPM even when Podfile exists without SDK', () async {
        // Create Podfile WITHOUT ULinkSDK
        await TestHelpers.createFile(
          tempDir,
          'Podfile',
          "pod 'SomeOtherPod'",
        );
        // Create Package.swift WITH ULinkSDK
        await TestHelpers.createFile(
          tempDir,
          'Package.swift',
          'dependencies: [.package(name: "ULinkSDK", url: "https://example.com")]',
        );

        final results = SdkPackageValidator.validate(tempDir.path, ProjectType.ios);

        expect(results.length, 1);
        expect(results[0].checkName, 'SDK Package - iOS (SPM)');
        expect(results[0].status, VerificationStatus.success);
      });
    });

    group('iOS - no SDK found', () {
      test('should return error when no Podfile or Package.swift', () async {
        final results = SdkPackageValidator.validate(tempDir.path, ProjectType.ios);

        expect(results.length, 1);
        expect(results[0].checkName, 'SDK Package - iOS');
        expect(results[0].status, VerificationStatus.error);
        expect(results[0].message, contains('not found'));
        expect(results[0].fixSuggestion, contains('Podfile'));
        expect(results[0].fixSuggestion, contains('Swift Package Manager'));
      });

      test('should return error when Podfile and Package.swift exist but neither has SDK', () async {
        await TestHelpers.createFile(
          tempDir,
          'Podfile',
          "pod 'SomeOtherPod'",
        );
        await TestHelpers.createFile(
          tempDir,
          'Package.swift',
          'let package = Package(name: "MyApp", dependencies: [])',
        );

        final results = SdkPackageValidator.validate(tempDir.path, ProjectType.ios);

        expect(results.length, 1);
        expect(results[0].checkName, 'SDK Package - iOS');
        expect(results[0].status, VerificationStatus.error);
      });
    });

    group('iOS - double-quoted pod', () {
      test('should detect ULinkSDK with double quotes in Podfile', () async {
        await TestHelpers.createFile(
          tempDir,
          'Podfile',
          'pod "ULinkSDK"',
        );
        await TestHelpers.createFile(
          tempDir,
          'Podfile.lock',
          'PODS:\n  - ULinkSDK (1.0.0)',
        );

        final results = SdkPackageValidator.validate(tempDir.path, ProjectType.ios);

        final podResult = results.firstWhere(
          (r) => r.checkName == 'SDK Package - iOS (CocoaPods)',
        );
        expect(podResult.status, VerificationStatus.success);
      });
    });
  });
}
