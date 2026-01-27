import 'dart:io';
import 'package:test/test.dart';
import 'package:ulink_cli/parsers/project_detector.dart';
import 'package:ulink_cli/models/platform_config.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('ProjectDetector', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await TestHelpers.createTempDir('project_detector_test_');
    });

    tearDown(() async {
      await TestHelpers.cleanupTempDir(tempDir);
    });

    group('detectProjectType', () {
      test('should detect Flutter project by pubspec.yaml', () async {
        await TestHelpers.createFile(
          tempDir,
          'pubspec.yaml',
          'name: test_app\ndependencies:\n  flutter:\n    sdk: flutter',
        );

        final result = ProjectDetector.detectProjectType(tempDir.path);

        expect(result, ProjectType.flutter);
      });

      test('should detect iOS project by ios directory', () async {
        await Directory('${tempDir.path}/ios').create(recursive: true);

        final result = ProjectDetector.detectProjectType(tempDir.path);

        expect(result, ProjectType.ios);
      });

      test('should detect iOS project by .xcodeproj directory', () async {
        await Directory('${tempDir.path}/MyApp.xcodeproj').create(recursive: true);

        final result = ProjectDetector.detectProjectType(tempDir.path);

        expect(result, ProjectType.ios);
      });

      test('should detect iOS project by .xcworkspace directory', () async {
        await Directory('${tempDir.path}/MyApp.xcworkspace').create(recursive: true);

        final result = ProjectDetector.detectProjectType(tempDir.path);

        expect(result, ProjectType.ios);
      });

      test('should detect Android project by android directory', () async {
        await Directory('${tempDir.path}/android').create(recursive: true);

        final result = ProjectDetector.detectProjectType(tempDir.path);

        expect(result, ProjectType.android);
      });

      test('should detect Android project by build.gradle', () async {
        await TestHelpers.createFile(
          tempDir,
          'build.gradle',
          'apply plugin: "com.android.application"',
        );

        final result = ProjectDetector.detectProjectType(tempDir.path);

        expect(result, ProjectType.android);
      });

      test('should detect Android project by build.gradle.kts', () async {
        await TestHelpers.createFile(
          tempDir,
          'build.gradle.kts',
          'plugins { id("com.android.application") }',
        );

        final result = ProjectDetector.detectProjectType(tempDir.path);

        expect(result, ProjectType.android);
      });

      test('should return unknown for empty directory', () async {
        final result = ProjectDetector.detectProjectType(tempDir.path);

        expect(result, ProjectType.unknown);
      });

      test('should return unknown for non-existent directory', () {
        final result = ProjectDetector.detectProjectType('/non/existent/path');

        expect(result, ProjectType.unknown);
      });

      test('should prioritize Flutter over iOS/Android', () async {
        // Flutter projects have pubspec.yaml plus ios/android directories
        await TestHelpers.createFile(
          tempDir,
          'pubspec.yaml',
          'name: test_app',
        );
        await Directory('${tempDir.path}/ios').create(recursive: true);
        await Directory('${tempDir.path}/android').create(recursive: true);

        final result = ProjectDetector.detectProjectType(tempDir.path);

        expect(result, ProjectType.flutter);
      });
    });

    group('findInfoPlist', () {
      test('should find Info.plist in Flutter project', () async {
        await TestHelpers.createFlutterProjectStructure(tempDir);

        final result = ProjectDetector.findInfoPlist(
          tempDir.path,
          ProjectType.flutter,
        );

        expect(result, isNotNull);
        expect(result!.path, contains('Info.plist'));
      });

      test('should find Info.plist in iOS project', () async {
        await TestHelpers.createFile(
          tempDir,
          'MyApp/Info.plist',
          '<?xml version="1.0"?><plist></plist>',
        );

        final result = ProjectDetector.findInfoPlist(
          tempDir.path,
          ProjectType.ios,
        );

        expect(result, isNotNull);
        expect(result!.path, endsWith('Info.plist'));
      });

      test('should return null when no Info.plist exists', () async {
        final result = ProjectDetector.findInfoPlist(
          tempDir.path,
          ProjectType.flutter,
        );

        expect(result, isNull);
      });
    });

    group('findEntitlements', () {
      test('should find entitlements in Flutter project', () async {
        await TestHelpers.createIosProjectStructure(
          tempDir,
          associatedDomains: ['example.com'],
        );

        final result = ProjectDetector.findEntitlements(
          tempDir.path,
          ProjectType.flutter,
        );

        expect(result, isNotNull);
        expect(result!.path, contains('.entitlements'));
      });

      test('should find entitlements in iOS project', () async {
        await TestHelpers.createFile(
          tempDir,
          'MyApp.entitlements',
          '<?xml version="1.0"?><plist></plist>',
        );

        final result = ProjectDetector.findEntitlements(
          tempDir.path,
          ProjectType.ios,
        );

        expect(result, isNotNull);
        expect(result!.path, endsWith('.entitlements'));
      });

      test('should return null when no entitlements exist', () async {
        final result = ProjectDetector.findEntitlements(
          tempDir.path,
          ProjectType.flutter,
        );

        expect(result, isNull);
      });
    });

    group('findAndroidManifest', () {
      test('should find manifest in Flutter project', () async {
        await TestHelpers.createAndroidProjectStructure(tempDir);

        final result = ProjectDetector.findAndroidManifest(
          tempDir.path,
          ProjectType.flutter,
        );

        expect(result, isNotNull);
        expect(result!.path, contains('AndroidManifest.xml'));
      });

      test('should find manifest in standard Android project location', () async {
        await TestHelpers.createFile(
          tempDir,
          'app/src/main/AndroidManifest.xml',
          '<?xml version="1.0"?><manifest></manifest>',
        );

        final result = ProjectDetector.findAndroidManifest(
          tempDir.path,
          ProjectType.android,
        );

        expect(result, isNotNull);
        expect(result!.path, endsWith('AndroidManifest.xml'));
      });

      test('should return null when no manifest exists', () async {
        final result = ProjectDetector.findAndroidManifest(
          tempDir.path,
          ProjectType.flutter,
        );

        expect(result, isNull);
      });
    });

    group('findPubspecYaml', () {
      test('should find pubspec.yaml', () async {
        await TestHelpers.createFile(
          tempDir,
          'pubspec.yaml',
          'name: test_app',
        );

        final result = ProjectDetector.findPubspecYaml(tempDir.path);

        expect(result, isNotNull);
        expect(result!.path, endsWith('pubspec.yaml'));
      });

      test('should return null when no pubspec.yaml exists', () async {
        final result = ProjectDetector.findPubspecYaml(tempDir.path);

        expect(result, isNull);
      });
    });

    group('findGradleFiles', () {
      test('should find gradle files in Flutter project', () async {
        await TestHelpers.createFile(
          tempDir,
          'android/app/build.gradle',
          'android {}',
        );
        await TestHelpers.createFile(
          tempDir,
          'android/build.gradle',
          'buildscript {}',
        );

        final result = ProjectDetector.findGradleFiles(
          tempDir.path,
          ProjectType.flutter,
        );

        expect(result.length, 2);
      });

      test('should find gradle.kts files in Flutter project', () async {
        await TestHelpers.createFile(
          tempDir,
          'android/app/build.gradle.kts',
          'android {}',
        );

        final result = ProjectDetector.findGradleFiles(
          tempDir.path,
          ProjectType.flutter,
        );

        expect(result.length, 1);
        expect(result[0].path, endsWith('build.gradle.kts'));
      });

      test('should return empty list when no gradle files exist', () async {
        final result = ProjectDetector.findGradleFiles(
          tempDir.path,
          ProjectType.flutter,
        );

        expect(result, isEmpty);
      });
    });

    group('findPodfile', () {
      test('should find Podfile in Flutter project', () async {
        await TestHelpers.createFile(
          tempDir,
          'ios/Podfile',
          'platform :ios, "12.0"',
        );

        final result = ProjectDetector.findPodfile(
          tempDir.path,
          ProjectType.flutter,
        );

        expect(result, isNotNull);
        expect(result!.path, endsWith('Podfile'));
      });

      test('should find Podfile in iOS project', () async {
        await TestHelpers.createFile(
          tempDir,
          'Podfile',
          'platform :ios, "12.0"',
        );

        final result = ProjectDetector.findPodfile(
          tempDir.path,
          ProjectType.ios,
        );

        expect(result, isNotNull);
      });

      test('should return null when no Podfile exists', () async {
        final result = ProjectDetector.findPodfile(
          tempDir.path,
          ProjectType.flutter,
        );

        expect(result, isNull);
      });
    });

    group('findAllEntitlements', () {
      test('should find all entitlements files in iOS project', () async {
        // Create multiple targets
        await TestHelpers.createFile(
          tempDir,
          'MyApp/MyApp.entitlements',
          '<?xml version="1.0"?><plist><dict></dict></plist>',
        );
        await TestHelpers.createFile(
          tempDir,
          'MyAppFree/MyAppFree.entitlements',
          '<?xml version="1.0"?><plist><dict></dict></plist>',
        );

        final result = ProjectDetector.findAllEntitlements(
          tempDir.path,
          ProjectType.ios,
        );

        expect(result.length, 2);
        expect(result.any((f) => f.path.contains('MyApp.entitlements')), isTrue);
        expect(result.any((f) => f.path.contains('MyAppFree.entitlements')), isTrue);
      });

      test('should return single entitlements for Flutter project', () async {
        await TestHelpers.createIosProjectStructure(
          tempDir,
          associatedDomains: ['example.com'],
        );

        final result = ProjectDetector.findAllEntitlements(
          tempDir.path,
          ProjectType.flutter,
        );

        expect(result.length, 1);
        expect(result.first.path, contains('Runner.entitlements'));
      });

      test('should return empty list when no entitlements exist', () async {
        final result = ProjectDetector.findAllEntitlements(
          tempDir.path,
          ProjectType.ios,
        );

        expect(result, isEmpty);
      });
    });

    group('findInfoPlistForEntitlements', () {
      test('should find Info.plist in same directory as entitlements', () async {
        await TestHelpers.createFile(
          tempDir,
          'MyApp/Info.plist',
          '<?xml version="1.0"?><plist><dict><key>CFBundleIdentifier</key><string>com.example.myapp</string></dict></plist>',
        );
        await TestHelpers.createFile(
          tempDir,
          'MyApp/MyApp.entitlements',
          '<?xml version="1.0"?><plist><dict></dict></plist>',
        );

        final entitlements = File('${tempDir.path}/MyApp/MyApp.entitlements');
        final result = ProjectDetector.findInfoPlistForEntitlements(entitlements);

        expect(result, isNotNull);
        expect(result!.path, contains('Info.plist'));
      });

      test('should find Info.plist in parent directory', () async {
        await TestHelpers.createFile(
          tempDir,
          'MyApp/Info.plist',
          '<?xml version="1.0"?><plist><dict></dict></plist>',
        );
        await TestHelpers.createFile(
          tempDir,
          'MyApp/Entitlements/MyApp.entitlements',
          '<?xml version="1.0"?><plist><dict></dict></plist>',
        );

        final entitlements = File('${tempDir.path}/MyApp/Entitlements/MyApp.entitlements');
        final result = ProjectDetector.findInfoPlistForEntitlements(entitlements);

        expect(result, isNotNull);
        expect(result!.path, contains('Info.plist'));
      });

      test('should find Info.plist in sibling directory', () async {
        await TestHelpers.createFile(
          tempDir,
          'MyApp/Resources/Info.plist',
          '<?xml version="1.0"?><plist><dict></dict></plist>',
        );
        await TestHelpers.createFile(
          tempDir,
          'MyApp/MyApp.entitlements',
          '<?xml version="1.0"?><plist><dict></dict></plist>',
        );

        final entitlements = File('${tempDir.path}/MyApp/MyApp.entitlements');
        final result = ProjectDetector.findInfoPlistForEntitlements(entitlements);

        expect(result, isNotNull);
        expect(result!.path, contains('Info.plist'));
      });

      test('should return null when no Info.plist found', () async {
        await TestHelpers.createFile(
          tempDir,
          'MyApp/MyApp.entitlements',
          '<?xml version="1.0"?><plist><dict></dict></plist>',
        );

        final entitlements = File('${tempDir.path}/MyApp/MyApp.entitlements');
        final result = ProjectDetector.findInfoPlistForEntitlements(entitlements);

        expect(result, isNull);
      });
    });
  });
}
