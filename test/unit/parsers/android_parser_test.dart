import 'dart:io';
import 'package:test/test.dart';
import 'package:ulink_cli/parsers/android_parser.dart';
import 'package:ulink_cli/models/platform_config.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('AndroidParser', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await TestHelpers.createTempDir('android_parser_test_');
    });

    tearDown(() async {
      await TestHelpers.cleanupTempDir(tempDir);
    });

    group('parseAndroidManifest', () {
      test('should extract package name from manifest package attribute', () async {
        final manifest = '''<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.example.testapp">
    <application android:label="Test App">
        <activity android:name=".MainActivity" />
    </application>
</manifest>''';

        final file = await TestHelpers.createFile(
          tempDir,
          'AndroidManifest.xml',
          manifest,
        );

        final result = AndroidParser.parseAndroidManifest(file);

        expect(result, isNotNull);
        expect(result!.packageName, 'com.example.testapp');
        expect(result.projectType, ProjectType.android);
      });

      test('should extract custom URL schemes from intent filters', () async {
        final manifest = '''<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.example.testapp">
    <application android:label="Test App">
        <activity android:name=".MainActivity">
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="myapp" />
            </intent-filter>
        </activity>
    </application>
</manifest>''';

        final file = await TestHelpers.createFile(
          tempDir,
          'AndroidManifest.xml',
          manifest,
        );

        final result = AndroidParser.parseAndroidManifest(file);

        expect(result, isNotNull);
        expect(result!.urlSchemes, contains('myapp'));
        expect(result.androidUrlSchemes, contains('myapp'));
      });

      test('should extract multiple URL schemes', () async {
        final manifest = '''<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.example.testapp">
    <application android:label="Test App">
        <activity android:name=".MainActivity">
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="myapp" />
            </intent-filter>
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="myapp-dev" />
            </intent-filter>
        </activity>
    </application>
</manifest>''';

        final file = await TestHelpers.createFile(
          tempDir,
          'AndroidManifest.xml',
          manifest,
        );

        final result = AndroidParser.parseAndroidManifest(file);

        expect(result, isNotNull);
        expect(result!.urlSchemes, containsAll(['myapp', 'myapp-dev']));
      });

      test('should extract App Link hosts with autoVerify', () async {
        final manifest = '''<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.example.testapp">
    <application android:label="Test App">
        <activity android:name=".MainActivity">
            <intent-filter android:autoVerify="true">
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="https" android:host="example.com" />
            </intent-filter>
        </activity>
    </application>
</manifest>''';

        final file = await TestHelpers.createFile(
          tempDir,
          'AndroidManifest.xml',
          manifest,
        );

        final result = AndroidParser.parseAndroidManifest(file);

        expect(result, isNotNull);
        expect(result!.appLinkHosts, contains('example.com'));
        expect(result.urlSchemes, isEmpty); // https should not be in urlSchemes
      });

      test('should extract multiple App Link hosts', () async {
        final manifest = '''<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.example.testapp">
    <application android:label="Test App">
        <activity android:name=".MainActivity">
            <intent-filter android:autoVerify="true">
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="https" android:host="example.com" />
            </intent-filter>
            <intent-filter android:autoVerify="true">
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="https" android:host="api.example.com" />
            </intent-filter>
        </activity>
    </application>
</manifest>''';

        final file = await TestHelpers.createFile(
          tempDir,
          'AndroidManifest.xml',
          manifest,
        );

        final result = AndroidParser.parseAndroidManifest(file);

        expect(result, isNotNull);
        expect(result!.appLinkHosts, containsAll(['example.com', 'api.example.com']));
      });

      test('should not include https hosts without autoVerify as App Links', () async {
        final manifest = '''<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.example.testapp">
    <application android:label="Test App">
        <activity android:name=".MainActivity">
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="https" android:host="example.com" />
            </intent-filter>
        </activity>
    </application>
</manifest>''';

        final file = await TestHelpers.createFile(
          tempDir,
          'AndroidManifest.xml',
          manifest,
        );

        final result = AndroidParser.parseAndroidManifest(file);

        expect(result, isNotNull);
        expect(result!.appLinkHosts, isEmpty);
      });

      test('should handle intent filters with both custom schemes and App Links', () async {
        final manifest = '''<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.example.testapp">
    <application android:label="Test App">
        <activity android:name=".MainActivity">
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="myapp" />
            </intent-filter>
            <intent-filter android:autoVerify="true">
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="https" android:host="example.com" />
            </intent-filter>
        </activity>
    </application>
</manifest>''';

        final file = await TestHelpers.createFile(
          tempDir,
          'AndroidManifest.xml',
          manifest,
        );

        final result = AndroidParser.parseAndroidManifest(file);

        expect(result, isNotNull);
        expect(result!.urlSchemes, contains('myapp'));
        expect(result.appLinkHosts, contains('example.com'));
      });

      test('should handle attributes without android: namespace prefix', () async {
        final manifest = '''<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.example.testapp">
    <application android:label="Test App">
        <activity android:name=".MainActivity">
            <intent-filter autoVerify="true">
                <action name="android.intent.action.VIEW" />
                <category name="android.intent.category.DEFAULT" />
                <category name="android.intent.category.BROWSABLE" />
                <data scheme="https" host="example.com" />
            </intent-filter>
        </activity>
    </application>
</manifest>''';

        final file = await TestHelpers.createFile(
          tempDir,
          'AndroidManifest.xml',
          manifest,
        );

        final result = AndroidParser.parseAndroidManifest(file);

        expect(result, isNotNull);
        expect(result!.appLinkHosts, contains('example.com'));
      });

      test('should return null for invalid XML', () async {
        final file = await TestHelpers.createFile(
          tempDir,
          'AndroidManifest.xml',
          'not valid xml content <<<<',
        );

        final result = AndroidParser.parseAndroidManifest(file);

        expect(result, isNull);
      });

      test('should handle empty manifest with no activities', () async {
        final manifest = '''<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.example.testapp">
    <application android:label="Test App">
    </application>
</manifest>''';

        final file = await TestHelpers.createFile(
          tempDir,
          'AndroidManifest.xml',
          manifest,
        );

        final result = AndroidParser.parseAndroidManifest(file);

        expect(result, isNotNull);
        expect(result!.packageName, 'com.example.testapp');
        expect(result.urlSchemes, isEmpty);
        expect(result.appLinkHosts, isEmpty);
      });

      test('should not duplicate URL schemes', () async {
        final manifest = '''<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.example.testapp">
    <application android:label="Test App">
        <activity android:name=".MainActivity">
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="myapp" />
            </intent-filter>
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <data android:scheme="myapp" />
            </intent-filter>
        </activity>
    </application>
</manifest>''';

        final file = await TestHelpers.createFile(
          tempDir,
          'AndroidManifest.xml',
          manifest,
        );

        final result = AndroidParser.parseAndroidManifest(file);

        expect(result, isNotNull);
        // Should not have duplicate entries
        expect(result!.urlSchemes.where((s) => s == 'myapp').length, 1);
      });

      test('should ignore intent filters without VIEW action', () async {
        final manifest = '''<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.example.testapp">
    <application android:label="Test App">
        <activity android:name=".MainActivity">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
            <intent-filter>
                <action android:name="android.intent.action.SEND" />
                <category android:name="android.intent.category.DEFAULT" />
                <data android:scheme="myapp" />
            </intent-filter>
        </activity>
    </application>
</manifest>''';

        final file = await TestHelpers.createFile(
          tempDir,
          'AndroidManifest.xml',
          manifest,
        );

        final result = AndroidParser.parseAndroidManifest(file);

        expect(result, isNotNull);
        expect(result!.urlSchemes, isEmpty);
      });

      test('should handle manifest without package attribute gracefully', () async {
        // When no package attribute and no gradle file found, packageName should be null
        final manifest = '''<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application android:label="Test App">
        <activity android:name=".MainActivity">
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="myapp" />
            </intent-filter>
        </activity>
    </application>
</manifest>''';

        final file = await TestHelpers.createFile(
          tempDir,
          'AndroidManifest.xml',
          manifest,
        );

        final result = AndroidParser.parseAndroidManifest(file);

        expect(result, isNotNull);
        // Package name will be null if not in manifest and no gradle namespace found
        expect(result!.packageName, isNull);
        // But URL schemes should still be extracted
        expect(result.urlSchemes, contains('myapp'));
      });
    });
  });
}
