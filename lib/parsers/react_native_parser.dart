import '../models/platform_config.dart';
import 'ios_parser.dart';
import 'android_parser.dart';
import 'project_detector.dart';

/// Parser for React Native / Expo projects (combines iOS and Android parsing).
///
/// React Native is cross-platform like Flutter, but its native directories only
/// exist for bare RN projects or after `expo prebuild`. When they are absent
/// (managed Expo workflow), the returned config simply has empty native fields
/// and the verifier reports that native config is plugin-managed.
class ReactNativeParser {
  static PlatformConfig? parseReactNativeProject(String projectPath) {
    try {
      // iOS configuration (ios/<App>/Info.plist + .entitlements)
      final infoPlist = ProjectDetector.findInfoPlist(
        projectPath,
        ProjectType.reactNative,
      );
      final entitlements = ProjectDetector.findEntitlements(
        projectPath,
        ProjectType.reactNative,
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

      // Android configuration (android/app/src/main/AndroidManifest.xml)
      final androidManifest = ProjectDetector.findAndroidManifest(
        projectPath,
        ProjectType.reactNative,
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

      final allUrlSchemes = <String>{
        ...iosUrlSchemes,
        ...androidUrlSchemes,
      }.toList();

      return PlatformConfig(
        projectType: ProjectType.reactNative,
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
