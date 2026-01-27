import 'dart:io';
import 'package:path/path.dart' as path;
import '../models/platform_config.dart';
import '../models/target_info.dart';
import 'ios_parser.dart';

/// Detects project type and finds configuration files
class ProjectDetector {
  /// Detect project type from directory structure
  static ProjectType detectProjectType(String projectPath) {
    final dir = Directory(projectPath);
    if (!dir.existsSync()) {
      return ProjectType.unknown;
    }

    // Check for Flutter project
    final pubspecFile = File(path.join(projectPath, 'pubspec.yaml'));
    if (pubspecFile.existsSync()) {
      return ProjectType.flutter;
    }

    // Check for iOS project
    final iosDir = Directory(path.join(projectPath, 'ios'));
    final xcodeprojFiles = Directory(projectPath)
        .listSync(recursive: false)
        .whereType<FileSystemEntity>()
        .where(
          (e) =>
              e.path.endsWith('.xcodeproj') || e.path.endsWith('.xcworkspace'),
        );
    if (iosDir.existsSync() || xcodeprojFiles.isNotEmpty) {
      return ProjectType.ios;
    }

    // Check for Android project
    final androidDir = Directory(path.join(projectPath, 'android'));
    final buildGradle = File(path.join(projectPath, 'build.gradle'));
    final buildGradleKts = File(path.join(projectPath, 'build.gradle.kts'));
    if (androidDir.existsSync() ||
        buildGradle.existsSync() ||
        buildGradleKts.existsSync()) {
      return ProjectType.android;
    }

    return ProjectType.unknown;
  }

  /// Find Info.plist file for iOS/Flutter projects
  static File? findInfoPlist(String projectPath, ProjectType projectType) {
    if (projectType == ProjectType.flutter) {
      // Check common Flutter iOS locations
      final paths = [
        path.join(projectPath, 'ios', 'Runner', 'Info.plist'),
        path.join(projectPath, 'ios', 'Runner', 'Runner-Info.plist'),
      ];
      for (final p in paths) {
        final file = File(p);
        if (file.existsSync()) return file;
      }
    } else if (projectType == ProjectType.ios) {
      // Search for Info.plist in iOS project
      final dir = Directory(projectPath);
      final files = dir.listSync(recursive: true).whereType<File>();
      for (final file in files) {
        if (file.path.endsWith('Info.plist')) {
          return file;
        }
      }
    }
    return null;
  }

  /// Find entitlements file for iOS/Flutter projects
  static File? findEntitlements(String projectPath, ProjectType projectType) {
    if (projectType == ProjectType.flutter) {
      final paths = [
        path.join(projectPath, 'ios', 'Runner', 'Runner.entitlements'),
      ];
      for (final p in paths) {
        final file = File(p);
        if (file.existsSync()) return file;
      }
    } else if (projectType == ProjectType.ios) {
      // Search for .entitlements files
      final dir = Directory(projectPath);
      final files = dir.listSync(recursive: true).whereType<File>();
      for (final file in files) {
        if (file.path.endsWith('.entitlements')) {
          return file;
        }
      }
    }
    return null;
  }

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

  /// Find AndroidManifest.xml for Android/Flutter projects
  static File? findAndroidManifest(
    String projectPath,
    ProjectType projectType,
  ) {
    if (projectType == ProjectType.flutter) {
      final manifestPath = path.join(
        projectPath,
        'android',
        'app',
        'src',
        'main',
        'AndroidManifest.xml',
      );
      final file = File(manifestPath);
      if (file.existsSync()) return file;
    } else if (projectType == ProjectType.android) {
      // For pure Android projects, check standard source locations first
      // Standard locations: app/src/main/AndroidManifest.xml or src/main/AndroidManifest.xml
      final standardPaths = [
        path.join(projectPath, 'app', 'src', 'main', 'AndroidManifest.xml'),
        path.join(projectPath, 'src', 'main', 'AndroidManifest.xml'),
      ];

      for (final manifestPath in standardPaths) {
        final file = File(manifestPath);
        if (file.existsSync()) {
          return file;
        }
      }

      // Fallback: Search recursively for AndroidManifest.xml (excluding build outputs)
      final dir = Directory(projectPath);
      final files = dir.listSync(recursive: true).whereType<File>();
      for (final file in files) {
        if (file.path.endsWith('AndroidManifest.xml') &&
            !file.path.contains('.gradle') &&
            !file.path.contains('build') &&
            file.path.contains('src') &&
            file.path.contains('main')) {
          return file;
        }
      }
    }
    return null;
  }

  /// Find pubspec.yaml for Flutter projects
  static File? findPubspecYaml(String projectPath) {
    final file = File(path.join(projectPath, 'pubspec.yaml'));
    return file.existsSync() ? file : null;
  }

  /// Find build.gradle or build.gradle.kts for Android/Flutter projects
  static List<File> findGradleFiles(
    String projectPath,
    ProjectType projectType,
  ) {
    final files = <File>[];

    if (projectType == ProjectType.flutter) {
      final paths = [
        path.join(projectPath, 'android', 'app', 'build.gradle'),
        path.join(projectPath, 'android', 'app', 'build.gradle.kts'),
        path.join(projectPath, 'android', 'build.gradle'),
        path.join(projectPath, 'android', 'build.gradle.kts'),
      ];
      for (final p in paths) {
        final file = File(p);
        if (file.existsSync()) files.add(file);
      }
    } else if (projectType == ProjectType.android) {
      final dir = Directory(projectPath);
      final gradleFiles = dir.listSync(recursive: true).whereType<File>().where(
        (f) {
          return f.path.endsWith('build.gradle') ||
              f.path.endsWith('build.gradle.kts');
        },
      );
      files.addAll(gradleFiles);
    }

    return files;
  }

  /// Find Podfile for iOS/Flutter projects
  static File? findPodfile(String projectPath, ProjectType projectType) {
    if (projectType == ProjectType.flutter) {
      final podfilePath = path.join(projectPath, 'ios', 'Podfile');
      final file = File(podfilePath);
      if (file.existsSync()) return file;
    } else if (projectType == ProjectType.ios) {
      final podfilePath = path.join(projectPath, 'Podfile');
      final file = File(podfilePath);
      if (file.existsSync()) return file;
    }
    return null;
  }

  /// Find Package.swift for iOS projects
  static File? findPackageSwift(String projectPath, ProjectType projectType) {
    if (projectType == ProjectType.ios || projectType == ProjectType.flutter) {
      final dir = Directory(projectPath);
      final files = dir.listSync(recursive: true).whereType<File>();
      for (final file in files) {
        if (file.path.endsWith('Package.swift')) {
          return file;
        }
      }
    }
    return null;
  }

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
}
