# Auto Target Detection by Bundle ID - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Automatically detect which iOS target to verify based on the bundle ID configured in ULink, supporting projects with multiple targets (paid/free versions).

**Architecture:** Fetch ULink config first to get the expected bundle ID, discover all entitlements files in the project, match each to its Info.plist to extract bundle IDs, then select the target matching the ULink bundle ID.

**Tech Stack:** Dart, plist_parser, existing test infrastructure with TestHelpers

---

## Task 1: Create TargetInfo Model

**Files:**
- Create: `lib/models/target_info.dart`
- Test: `test/unit/models/target_info_test.dart`

**Step 1: Write the test file**

```dart
import 'dart:io';
import 'package:test/test.dart';
import 'package:ulink_cli/models/target_info.dart';

void main() {
  group('TargetInfo', () {
    test('should create TargetInfo with all fields', () {
      final entitlements = File('/path/to/MyApp.entitlements');
      final infoPlist = File('/path/to/Info.plist');

      final target = TargetInfo(
        entitlementsFile: entitlements,
        infoPlistFile: infoPlist,
        bundleId: 'com.example.myapp',
        targetName: 'MyApp',
      );

      expect(target.entitlementsFile, entitlements);
      expect(target.infoPlistFile, infoPlist);
      expect(target.bundleId, 'com.example.myapp');
      expect(target.targetName, 'MyApp');
    });
  });

  group('TargetDiscoveryResult', () {
    test('hasMatch returns true when matchedTarget is not null', () {
      final target = TargetInfo(
        entitlementsFile: File('/path/to/MyApp.entitlements'),
        infoPlistFile: File('/path/to/Info.plist'),
        bundleId: 'com.example.myapp',
        targetName: 'MyApp',
      );

      final result = TargetDiscoveryResult(
        matchedTarget: target,
        allTargets: [target],
        requestedBundleId: 'com.example.myapp',
      );

      expect(result.hasMatch, isTrue);
    });

    test('hasMatch returns false when matchedTarget is null', () {
      final result = TargetDiscoveryResult(
        matchedTarget: null,
        allTargets: [],
        requestedBundleId: 'com.example.myapp',
      );

      expect(result.hasMatch, isFalse);
    });

    test('hasMultipleTargets returns true when more than one target', () {
      final target1 = TargetInfo(
        entitlementsFile: File('/path/to/MyApp.entitlements'),
        infoPlistFile: File('/path/to/Info.plist'),
        bundleId: 'com.example.myapp',
        targetName: 'MyApp',
      );
      final target2 = TargetInfo(
        entitlementsFile: File('/path/to/MyAppFree.entitlements'),
        infoPlistFile: File('/path/to/Info.plist'),
        bundleId: 'com.example.myappfree',
        targetName: 'MyAppFree',
      );

      final result = TargetDiscoveryResult(
        matchedTarget: target1,
        allTargets: [target1, target2],
        requestedBundleId: 'com.example.myapp',
      );

      expect(result.hasMultipleTargets, isTrue);
    });

    test('hasMultipleTargets returns false when one or zero targets', () {
      final result = TargetDiscoveryResult(
        matchedTarget: null,
        allTargets: [],
        requestedBundleId: null,
      );

      expect(result.hasMultipleTargets, isFalse);
    });
  });
}
```

**Step 2: Run test to verify it fails**

```bash
cd /Users/mohn93/Desktop/all_ulink/ulink_cli && dart test test/unit/models/target_info_test.dart
```

Expected: FAIL - file not found

**Step 3: Write the implementation**

```dart
import 'dart:io';

/// Information about an iOS target discovered in the project
class TargetInfo {
  final File entitlementsFile;
  final File infoPlistFile;
  final String bundleId;
  final String targetName;

  TargetInfo({
    required this.entitlementsFile,
    required this.infoPlistFile,
    required this.bundleId,
    required this.targetName,
  });
}

/// Result of target discovery operation
class TargetDiscoveryResult {
  final TargetInfo? matchedTarget;
  final List<TargetInfo> allTargets;
  final String? requestedBundleId;

  TargetDiscoveryResult({
    required this.matchedTarget,
    required this.allTargets,
    required this.requestedBundleId,
  });

  /// Whether a matching target was found
  bool get hasMatch => matchedTarget != null;

  /// Whether multiple targets were discovered in the project
  bool get hasMultipleTargets => allTargets.length > 1;
}
```

**Step 4: Run test to verify it passes**

```bash
cd /Users/mohn93/Desktop/all_ulink/ulink_cli && dart test test/unit/models/target_info_test.dart
```

Expected: PASS

**Step 5: Commit**

```bash
cd /Users/mohn93/Desktop/all_ulink/ulink_cli && git add lib/models/target_info.dart test/unit/models/target_info_test.dart && git commit -m "$(cat <<'EOF'
feat: add TargetInfo and TargetDiscoveryResult models

New data structures for multi-target iOS project support:
- TargetInfo holds entitlements file, Info.plist, bundle ID, and target name
- TargetDiscoveryResult holds matched target and all discovered targets
EOF
)"
```

---

## Task 2: Add findAllEntitlements to ProjectDetector

**Files:**
- Modify: `lib/parsers/project_detector.dart`
- Test: `test/unit/parsers/project_detector_test.dart`

**Step 1: Add test cases**

Add to `test/unit/parsers/project_detector_test.dart` inside the main group:

```dart
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
```

**Step 2: Run test to verify it fails**

```bash
cd /Users/mohn93/Desktop/all_ulink/ulink_cli && dart test test/unit/parsers/project_detector_test.dart --name "findAllEntitlements"
```

Expected: FAIL - method not found

**Step 3: Add implementation to ProjectDetector**

Add this method to `lib/parsers/project_detector.dart`:

```dart
  /// Find all entitlements files for iOS/Flutter projects
  static List<File> findAllEntitlements(String projectPath, ProjectType projectType) {
    final entitlements = <File>[];

    if (projectType == ProjectType.flutter) {
      // Flutter has a single well-known location
      final flutterEntitlements = File(
        path.join(projectPath, 'ios', 'Runner', 'Runner.entitlements'),
      );
      if (flutterEntitlements.existsSync()) {
        entitlements.add(flutterEntitlements);
      }
    } else if (projectType == ProjectType.ios) {
      // Search for all .entitlements files
      final dir = Directory(projectPath);
      if (dir.existsSync()) {
        final files = dir.listSync(recursive: true).whereType<File>();
        for (final file in files) {
          if (file.path.endsWith('.entitlements')) {
            entitlements.add(file);
          }
        }
      }
    }

    return entitlements;
  }
```

**Step 4: Run test to verify it passes**

```bash
cd /Users/mohn93/Desktop/all_ulink/ulink_cli && dart test test/unit/parsers/project_detector_test.dart --name "findAllEntitlements"
```

Expected: PASS

**Step 5: Commit**

```bash
cd /Users/mohn93/Desktop/all_ulink/ulink_cli && git add lib/parsers/project_detector.dart test/unit/parsers/project_detector_test.dart && git commit -m "$(cat <<'EOF'
feat: add findAllEntitlements to ProjectDetector

Returns all entitlements files found in iOS projects, enabling
multi-target support for projects with paid/free versions.
EOF
)"
```

---

## Task 3: Add findInfoPlistForEntitlements Helper

**Files:**
- Modify: `lib/parsers/project_detector.dart`
- Test: `test/unit/parsers/project_detector_test.dart`

**Step 1: Add test cases**

Add to `test/unit/parsers/project_detector_test.dart`:

```dart
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
```

**Step 2: Run test to verify it fails**

```bash
cd /Users/mohn93/Desktop/all_ulink/ulink_cli && dart test test/unit/parsers/project_detector_test.dart --name "findInfoPlistForEntitlements"
```

Expected: FAIL - method not found

**Step 3: Add implementation**

Add to `lib/parsers/project_detector.dart`:

```dart
  /// Find the Info.plist associated with an entitlements file
  /// Searches: same directory, parent directory, sibling directories, recursive in target folder
  static File? findInfoPlistForEntitlements(File entitlementsFile) {
    final entitlementsDir = entitlementsFile.parent;

    // 1. Check same directory
    final sameDirPlist = File(path.join(entitlementsDir.path, 'Info.plist'));
    if (sameDirPlist.existsSync()) {
      return sameDirPlist;
    }

    // 2. Check parent directory
    final parentDir = entitlementsDir.parent;
    final parentPlist = File(path.join(parentDir.path, 'Info.plist'));
    if (parentPlist.existsSync()) {
      return parentPlist;
    }

    // 3. Check sibling directories (one level deep from entitlements directory)
    if (entitlementsDir.existsSync()) {
      for (final entity in entitlementsDir.listSync()) {
        if (entity is Directory) {
          final siblingPlist = File(path.join(entity.path, 'Info.plist'));
          if (siblingPlist.existsSync()) {
            return siblingPlist;
          }
        }
      }
    }

    // 4. Check sibling directories from parent
    if (parentDir.existsSync()) {
      for (final entity in parentDir.listSync()) {
        if (entity is Directory) {
          final siblingPlist = File(path.join(entity.path, 'Info.plist'));
          if (siblingPlist.existsSync()) {
            return siblingPlist;
          }
        }
      }
    }

    // 5. Recursive search within target folder (entitlements directory and below)
    if (entitlementsDir.existsSync()) {
      for (final entity in entitlementsDir.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('Info.plist')) {
          return entity;
        }
      }
    }

    return null;
  }
```

**Step 4: Run test to verify it passes**

```bash
cd /Users/mohn93/Desktop/all_ulink/ulink_cli && dart test test/unit/parsers/project_detector_test.dart --name "findInfoPlistForEntitlements"
```

Expected: PASS

**Step 5: Commit**

```bash
cd /Users/mohn93/Desktop/all_ulink/ulink_cli && git add lib/parsers/project_detector.dart test/unit/parsers/project_detector_test.dart && git commit -m "$(cat <<'EOF'
feat: add findInfoPlistForEntitlements to ProjectDetector

Finds the Info.plist associated with an entitlements file by searching:
same directory, parent directory, sibling directories, and recursively.
EOF
)"
```

---

## Task 4: Add discoverTargetByBundleId Method

**Files:**
- Modify: `lib/parsers/project_detector.dart`
- Test: `test/unit/parsers/project_detector_test.dart`

**Step 1: Add import to project_detector.dart**

Add at the top of `lib/parsers/project_detector.dart`:

```dart
import '../models/target_info.dart';
import 'ios_parser.dart';
```

**Step 2: Add test cases**

Add to `test/unit/parsers/project_detector_test.dart`:

```dart
    group('discoverTargetByBundleId', () {
      test('should match target by bundle ID', () async {
        // Create two targets
        await TestHelpers.createFile(
          tempDir,
          'MyApp/Info.plist',
          '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.example.myapp</string>
</dict>
</plist>''',
        );
        await TestHelpers.createFile(
          tempDir,
          'MyApp/MyApp.entitlements',
          '<?xml version="1.0"?><plist><dict></dict></plist>',
        );

        await TestHelpers.createFile(
          tempDir,
          'MyAppFree/Info.plist',
          '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.example.myappfree</string>
</dict>
</plist>''',
        );
        await TestHelpers.createFile(
          tempDir,
          'MyAppFree/MyAppFree.entitlements',
          '<?xml version="1.0"?><plist><dict></dict></plist>',
        );

        final result = ProjectDetector.discoverTargetByBundleId(
          tempDir.path,
          ProjectType.ios,
          'com.example.myappfree',
        );

        expect(result.hasMatch, isTrue);
        expect(result.matchedTarget!.bundleId, 'com.example.myappfree');
        expect(result.matchedTarget!.targetName, 'MyAppFree');
        expect(result.allTargets.length, 2);
      });

      test('should return all targets when no bundle ID provided', () async {
        await TestHelpers.createFile(
          tempDir,
          'MyApp/Info.plist',
          '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.example.myapp</string>
</dict>
</plist>''',
        );
        await TestHelpers.createFile(
          tempDir,
          'MyApp/MyApp.entitlements',
          '<?xml version="1.0"?><plist><dict></dict></plist>',
        );

        final result = ProjectDetector.discoverTargetByBundleId(
          tempDir.path,
          ProjectType.ios,
          null,
        );

        expect(result.hasMatch, isTrue);
        expect(result.matchedTarget!.bundleId, 'com.example.myapp');
        expect(result.allTargets.length, 1);
      });

      test('should return no match when bundle ID not found', () async {
        await TestHelpers.createFile(
          tempDir,
          'MyApp/Info.plist',
          '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.example.myapp</string>
</dict>
</plist>''',
        );
        await TestHelpers.createFile(
          tempDir,
          'MyApp/MyApp.entitlements',
          '<?xml version="1.0"?><plist><dict></dict></plist>',
        );

        final result = ProjectDetector.discoverTargetByBundleId(
          tempDir.path,
          ProjectType.ios,
          'com.example.different',
        );

        expect(result.hasMatch, isFalse);
        expect(result.allTargets.length, 1);
        expect(result.requestedBundleId, 'com.example.different');
      });

      test('should derive target name from parent folder', () async {
        await TestHelpers.createFile(
          tempDir,
          'MyAwesomeApp/Info.plist',
          '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.example.app</string>
</dict>
</plist>''',
        );
        await TestHelpers.createFile(
          tempDir,
          'MyAwesomeApp/MyAwesomeApp.entitlements',
          '<?xml version="1.0"?><plist><dict></dict></plist>',
        );

        final result = ProjectDetector.discoverTargetByBundleId(
          tempDir.path,
          ProjectType.ios,
          'com.example.app',
        );

        expect(result.matchedTarget!.targetName, 'MyAwesomeApp');
      });

      test('should return empty targets when no entitlements found', () async {
        final result = ProjectDetector.discoverTargetByBundleId(
          tempDir.path,
          ProjectType.ios,
          'com.example.app',
        );

        expect(result.hasMatch, isFalse);
        expect(result.allTargets, isEmpty);
      });
    });
```

**Step 3: Run test to verify it fails**

```bash
cd /Users/mohn93/Desktop/all_ulink/ulink_cli && dart test test/unit/parsers/project_detector_test.dart --name "discoverTargetByBundleId"
```

Expected: FAIL - method not found

**Step 4: Add implementation**

Add to `lib/parsers/project_detector.dart`:

```dart
  /// Discover iOS target by bundle ID
  /// Returns all discovered targets plus the one matching the requested bundle ID
  static TargetDiscoveryResult discoverTargetByBundleId(
    String projectPath,
    ProjectType projectType,
    String? targetBundleId,
  ) {
    final allEntitlements = findAllEntitlements(projectPath, projectType);
    final allTargets = <TargetInfo>[];
    TargetInfo? matchedTarget;

    for (final entitlementsFile in allEntitlements) {
      final infoPlist = findInfoPlistForEntitlements(entitlementsFile);
      if (infoPlist == null) {
        // Skip entitlements without associated Info.plist
        continue;
      }

      // Parse bundle ID from Info.plist
      final config = IosParser.parseInfoPlist(infoPlist);
      if (config == null || config.bundleIdentifier == null) {
        continue;
      }

      // Derive target name from parent folder of entitlements file
      final targetName = path.basename(entitlementsFile.parent.path);

      final target = TargetInfo(
        entitlementsFile: entitlementsFile,
        infoPlistFile: infoPlist,
        bundleId: config.bundleIdentifier!,
        targetName: targetName,
      );

      allTargets.add(target);

      // Check if this matches the requested bundle ID
      if (targetBundleId == null) {
        // No specific bundle ID requested, match first target
        matchedTarget ??= target;
      } else if (config.bundleIdentifier == targetBundleId) {
        matchedTarget = target;
      }
    }

    return TargetDiscoveryResult(
      matchedTarget: matchedTarget,
      allTargets: allTargets,
      requestedBundleId: targetBundleId,
    );
  }
```

**Step 5: Run test to verify it passes**

```bash
cd /Users/mohn93/Desktop/all_ulink/ulink_cli && dart test test/unit/parsers/project_detector_test.dart --name "discoverTargetByBundleId"
```

Expected: PASS

**Step 6: Commit**

```bash
cd /Users/mohn93/Desktop/all_ulink/ulink_cli && git add lib/parsers/project_detector.dart test/unit/parsers/project_detector_test.dart && git commit -m "$(cat <<'EOF'
feat: add discoverTargetByBundleId to ProjectDetector

Discovers all iOS targets in a project and matches by bundle ID.
Derives target name from parent folder of entitlements file.
EOF
)"
```

---

## Task 5: Update VerifyCommand to Use Target Discovery

**Files:**
- Modify: `lib/commands/verify_command.dart`

**Step 1: Add import**

Add at top of `lib/commands/verify_command.dart`:

```dart
import '../models/target_info.dart';
```

**Step 2: Update the iOS parsing section**

Replace the iOS project parsing block (around lines 82-106) with new logic that uses target discovery. The key change is to fetch ULink config first when credentials exist, then use that bundle ID to discover the correct target.

See the implementation in Step 3.

**Step 3: Implement the changes**

The changes are extensive - modifying the flow to:
1. Check for credentials early
2. Fetch ULink config early for iOS projects
3. Use `discoverTargetByBundleId` with the ULink bundle ID
4. Show helpful error messages when no match found

This requires careful restructuring of the verify command. The changes are:

1. Move the credential check and ULink config fetch BEFORE local parsing for iOS
2. Use discovered target for iOS parsing
3. Add error handling for multi-target scenarios

**Step 4: Test manually**

```bash
cd /Users/mohn93/Desktop/all_ulink/ulink_cli && dart run bin/ulink.dart verify --help
```

**Step 5: Commit**

```bash
cd /Users/mohn93/Desktop/all_ulink/ulink_cli && git add lib/commands/verify_command.dart && git commit -m "$(cat <<'EOF'
feat: use auto target detection in verify command

For iOS projects with multiple targets, automatically detects which
target to verify based on the bundle ID configured in ULink.
Shows helpful error message listing all discovered targets when
no match is found.
EOF
)"
```

---

## Task 6: Run Full Test Suite

**Step 1: Run all tests**

```bash
cd /Users/mohn93/Desktop/all_ulink/ulink_cli && dart test
```

Expected: All tests pass

**Step 2: Manual integration test**

Test with a multi-target iOS project if available, or create a test project structure.

**Step 3: Final commit if any fixes needed**

```bash
cd /Users/mohn93/Desktop/all_ulink/ulink_cli && git status
```
