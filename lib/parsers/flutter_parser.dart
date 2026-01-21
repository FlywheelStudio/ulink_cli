import 'dart:io';
import 'package:yaml/yaml.dart';
import '../models/platform_config.dart';
import 'ios_parser.dart';
import 'android_parser.dart';
import 'project_detector.dart';

/// Parser for Flutter projects (combines iOS and Android parsing)
class FlutterParser {
  /// Parse Flutter project configuration
  static PlatformConfig? parseFlutterProject(String projectPath) {
    try {
      // Parse pubspec.yaml for basic info
      final pubspecFile = ProjectDetector.findPubspecYaml(projectPath);
      if (pubspecFile == null) {
        return null;
      }

      final content = pubspecFile.readAsStringSync();
      final yaml = loadYaml(content) as Map;
      final packageName = yaml['name'] as String?;

      // Parse iOS configuration
      final infoPlist = ProjectDetector.findInfoPlist(
        projectPath,
        ProjectType.flutter,
      );
      final entitlements = ProjectDetector.findEntitlements(
        projectPath,
        ProjectType.flutter,
      );

      String? bundleIdentifier;
      List<String> iosUrlSchemes = [];
      List<String> associatedDomains = [];

      if (infoPlist != null) {
        final iosConfig = IosParser.parseInfoPlist(infoPlist);
        bundleIdentifier = iosConfig?.bundleIdentifier;
        iosUrlSchemes = iosConfig?.urlSchemes ?? [];
      }

      if (entitlements != null) {
        associatedDomains = IosParser.parseEntitlements(entitlements);
      }

      // Parse Android configuration
      final androidManifest = ProjectDetector.findAndroidManifest(
        projectPath,
        ProjectType.flutter,
      );
      String? androidPackageName;
      List<String> androidUrlSchemes = [];
      List<String> appLinkHosts = [];

      if (androidManifest != null) {
        final androidConfig = AndroidParser.parseAndroidManifest(
          androidManifest,
        );
        androidPackageName = androidConfig?.packageName;
        androidUrlSchemes = androidConfig?.urlSchemes ?? [];
        appLinkHosts = androidConfig?.appLinkHosts ?? [];
      }

      // Combine iOS and Android URL schemes
      final allUrlSchemes = <String>{
        ...iosUrlSchemes,
        ...androidUrlSchemes,
      }.toList();

      return PlatformConfig(
        projectType: ProjectType.flutter,
        bundleIdentifier: bundleIdentifier,
        packageName: androidPackageName,
        urlSchemes: allUrlSchemes,
        iosUrlSchemes: iosUrlSchemes,
        androidUrlSchemes: androidUrlSchemes,
        associatedDomains: associatedDomains,
        appLinkHosts: appLinkHosts,
      );
    } catch (e) {
      return null;
    }
  }
}
