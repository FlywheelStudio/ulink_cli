import 'dart:io';
import 'package:test/test.dart';
import 'package:ulink_cli/parsers/ios_parser.dart';
import 'package:ulink_cli/models/platform_config.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('IosParser', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await TestHelpers.createTempDir('ios_parser_test_');
    });

    tearDown(() async {
      await TestHelpers.cleanupTempDir(tempDir);
    });

    group('parseInfoPlist', () {
      test('should extract bundle identifier from plist', () async {
        final plist = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.example.testapp</string>
</dict>
</plist>''';

        final file = await TestHelpers.createFile(
          tempDir,
          'Info.plist',
          plist,
        );

        final result = IosParser.parseInfoPlist(file);

        expect(result, isNotNull);
        expect(result!.bundleIdentifier, 'com.example.testapp');
        expect(result.projectType, ProjectType.ios);
      });

      test('should extract URL schemes from CFBundleURLTypes', () async {
        final plist = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.example.testapp</string>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>myapp</string>
            </array>
        </dict>
    </array>
</dict>
</plist>''';

        final file = await TestHelpers.createFile(
          tempDir,
          'Info.plist',
          plist,
        );

        final result = IosParser.parseInfoPlist(file);

        expect(result, isNotNull);
        expect(result!.urlSchemes, contains('myapp'));
        expect(result.iosUrlSchemes, contains('myapp'));
      });

      test('should extract multiple URL schemes', () async {
        final plist = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.example.testapp</string>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>myapp</string>
                <string>myapp-dev</string>
            </array>
        </dict>
        <dict>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>myapp-staging</string>
            </array>
        </dict>
    </array>
</dict>
</plist>''';

        final file = await TestHelpers.createFile(
          tempDir,
          'Info.plist',
          plist,
        );

        final result = IosParser.parseInfoPlist(file);

        expect(result, isNotNull);
        expect(result!.urlSchemes, containsAll(['myapp', 'myapp-dev', 'myapp-staging']));
      });

      test('should return null for invalid plist', () async {
        final file = await TestHelpers.createFile(
          tempDir,
          'Info.plist',
          'not valid plist content <<<<',
        );

        final result = IosParser.parseInfoPlist(file);

        expect(result, isNull);
      });

      test('should handle plist without URL schemes', () async {
        final plist = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.example.testapp</string>
</dict>
</plist>''';

        final file = await TestHelpers.createFile(
          tempDir,
          'Info.plist',
          plist,
        );

        final result = IosParser.parseInfoPlist(file);

        expect(result, isNotNull);
        expect(result!.bundleIdentifier, 'com.example.testapp');
        expect(result.urlSchemes, isEmpty);
      });

      test('should handle empty CFBundleURLTypes array', () async {
        final plist = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.example.testapp</string>
    <key>CFBundleURLTypes</key>
    <array>
    </array>
</dict>
</plist>''';

        final file = await TestHelpers.createFile(
          tempDir,
          'Info.plist',
          plist,
        );

        final result = IosParser.parseInfoPlist(file);

        expect(result, isNotNull);
        expect(result!.urlSchemes, isEmpty);
      });

      test('should resolve PRODUCT_BUNDLE_IDENTIFIER from pbxproj', () async {
        // Create .xcodeproj directory structure
        final pbxproj = '// !\$*UTF8*\$!\n'
            '{\n'
            '  buildSettings = {\n'
            '    PRODUCT_BUNDLE_IDENTIFIER = com.example.resolved;\n'
            '  };\n'
            '}';

        await TestHelpers.createFile(
          tempDir,
          'Runner.xcodeproj/project.pbxproj',
          pbxproj,
        );

        final plist = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>\$(PRODUCT_BUNDLE_IDENTIFIER)</string>
</dict>
</plist>''';

        final file = await TestHelpers.createFile(
          tempDir,
          'Info.plist',
          plist,
        );

        final result = IosParser.parseInfoPlist(file);

        expect(result, isNotNull);
        expect(result!.bundleIdentifier, 'com.example.resolved');
      });

      test('should extract team ID from pbxproj', () async {
        final pbxproj = '// !\$*UTF8*\$!\n'
            '{\n'
            '  buildSettings = {\n'
            '    DEVELOPMENT_TEAM = ABC123DEFG;\n'
            '    PRODUCT_BUNDLE_IDENTIFIER = com.example.testapp;\n'
            '  };\n'
            '}';

        await TestHelpers.createFile(
          tempDir,
          'Runner.xcodeproj/project.pbxproj',
          pbxproj,
        );

        final plist = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.example.testapp</string>
</dict>
</plist>''';

        final file = await TestHelpers.createFile(
          tempDir,
          'Info.plist',
          plist,
        );

        final result = IosParser.parseInfoPlist(file);

        expect(result, isNotNull);
        expect(result!.teamId, 'ABC123DEFG');
      });

      test('should handle quoted team ID in pbxproj', () async {
        final pbxproj = '// !\$*UTF8*\$!\n'
            '{\n'
            '  buildSettings = {\n'
            '    DEVELOPMENT_TEAM = "XYZ987ABCD";\n'
            '    PRODUCT_BUNDLE_IDENTIFIER = com.example.testapp;\n'
            '  };\n'
            '}';

        await TestHelpers.createFile(
          tempDir,
          'Runner.xcodeproj/project.pbxproj',
          pbxproj,
        );

        final plist = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.example.testapp</string>
</dict>
</plist>''';

        final file = await TestHelpers.createFile(
          tempDir,
          'Info.plist',
          plist,
        );

        final result = IosParser.parseInfoPlist(file);

        expect(result, isNotNull);
        expect(result!.teamId, 'XYZ987ABCD');
      });
    });

    group('parseEntitlements', () {
      test('should extract associated domains from entitlements', () async {
        final entitlements = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.associated-domains</key>
    <array>
        <string>applinks:example.com</string>
    </array>
</dict>
</plist>''';

        final file = await TestHelpers.createFile(
          tempDir,
          'Runner.entitlements',
          entitlements,
        );

        final result = IosParser.parseEntitlements(file);

        expect(result, contains('example.com'));
      });

      test('should extract multiple associated domains', () async {
        final entitlements = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.associated-domains</key>
    <array>
        <string>applinks:example.com</string>
        <string>applinks:api.example.com</string>
        <string>applinks:*.example.com</string>
    </array>
</dict>
</plist>''';

        final file = await TestHelpers.createFile(
          tempDir,
          'Runner.entitlements',
          entitlements,
        );

        final result = IosParser.parseEntitlements(file);

        expect(result, containsAll(['example.com', 'api.example.com', '*.example.com']));
      });

      test('should remove applinks: prefix', () async {
        final entitlements = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.associated-domains</key>
    <array>
        <string>applinks:test.example.com</string>
    </array>
</dict>
</plist>''';

        final file = await TestHelpers.createFile(
          tempDir,
          'Runner.entitlements',
          entitlements,
        );

        final result = IosParser.parseEntitlements(file);

        expect(result, contains('test.example.com'));
        expect(result.any((d) => d.contains('applinks:')), isFalse);
      });

      test('should return empty list for entitlements without associated domains', () async {
        final entitlements = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.example.testapp</string>
    </array>
</dict>
</plist>''';

        final file = await TestHelpers.createFile(
          tempDir,
          'Runner.entitlements',
          entitlements,
        );

        final result = IosParser.parseEntitlements(file);

        expect(result, isEmpty);
      });

      test('should return empty list for invalid entitlements', () async {
        final file = await TestHelpers.createFile(
          tempDir,
          'Runner.entitlements',
          'not valid plist <<<<',
        );

        final result = IosParser.parseEntitlements(file);

        expect(result, isEmpty);
      });

      test('should handle domains without applinks prefix', () async {
        final entitlements = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.associated-domains</key>
    <array>
        <string>example.com</string>
    </array>
</dict>
</plist>''';

        final file = await TestHelpers.createFile(
          tempDir,
          'Runner.entitlements',
          entitlements,
        );

        final result = IosParser.parseEntitlements(file);

        expect(result, contains('example.com'));
      });
    });

    group('extractTeamId', () {
      test('should extract team ID from bundle identifier with team prefix', () {
        final result = IosParser.extractTeamId('ABC123DEFG.com.example.app');

        expect(result, 'ABC123DEFG');
      });

      test('should return null for standard bundle identifier', () {
        final result = IosParser.extractTeamId('com.example.app');

        expect(result, isNull);
      });

      test('should return null for null bundle identifier', () {
        final result = IosParser.extractTeamId(null);

        expect(result, isNull);
      });

      test('should not extract invalid team ID format', () {
        // Team IDs are 10 alphanumeric characters
        final result = IosParser.extractTeamId('abc.com.example.app');

        expect(result, isNull);
      });
    });
  });
}
