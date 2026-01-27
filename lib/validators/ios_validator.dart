import 'dart:io';
import '../models/verification_result.dart';
import '../models/platform_config.dart';
import '../parsers/ios_parser.dart';
import '../parsers/project_detector.dart';

/// Validator for iOS configuration files
class IosValidator {
  /// Validate iOS project configuration
  static List<VerificationResult> validate(
    String projectPath,
    PlatformConfig? platformConfig,
  ) {
    final results = <VerificationResult>[];

    // Check Info.plist
    final infoPlist = ProjectDetector.findInfoPlist(
      projectPath,
      platformConfig?.projectType ?? ProjectType.ios,
    );

    if (infoPlist == null) {
      results.add(
        VerificationResult(
          checkName: 'iOS Info.plist',
          status: VerificationStatus.error,
          message: 'Info.plist not found',
          fixSuggestion: 'Ensure Info.plist exists in your iOS project',
        ),
      );
      return results;
    }

    results.add(
      VerificationResult(
        checkName: 'iOS Info.plist',
        status: VerificationStatus.success,
        message: 'Info.plist found',
        details: {'path': infoPlist.path},
      ),
    );

    // Check CFBundleURLTypes
    if (platformConfig != null) {
      if (platformConfig.urlSchemes.isEmpty) {
        results.add(
          VerificationResult(
            checkName: 'iOS URL Schemes',
            status: VerificationStatus.warning,
            message: 'No URL schemes found in Info.plist',
            fixSuggestion:
                'Add CFBundleURLTypes with CFBundleURLSchemes to Info.plist',
          ),
        );
      } else {
        results.add(
          VerificationResult(
            checkName: 'iOS URL Schemes',
            status: VerificationStatus.success,
            message:
                'URL schemes found: ${platformConfig.urlSchemes.join(", ")}',
          ),
        );
      }

      // Check bundle identifier
      if (platformConfig.bundleIdentifier == null) {
        results.add(
          VerificationResult(
            checkName: 'iOS Bundle Identifier',
            status: VerificationStatus.error,
            message: 'Bundle identifier not found in Info.plist',
            fixSuggestion: 'Add CFBundleIdentifier to Info.plist',
          ),
        );
      }
    }

    // Check associated domains from platformConfig (already parsed from correct target)
    // This avoids re-parsing entitlements which could pick up the wrong file in multi-target projects
    if (platformConfig != null && platformConfig.associatedDomains.isNotEmpty) {
      results.add(
        VerificationResult(
          checkName: 'iOS Associated Domains',
          status: VerificationStatus.success,
          message:
              'Associated domains found: ${platformConfig.associatedDomains.join(", ")}',
        ),
      );
    } else {
      // Fallback: try to find and parse entitlements file directly
      final entitlements = ProjectDetector.findEntitlements(
        projectPath,
        platformConfig?.projectType ?? ProjectType.ios,
      );

      if (entitlements == null) {
        results.add(
          VerificationResult(
            checkName: 'iOS Entitlements',
            status: VerificationStatus.warning,
            message: 'Entitlements file not found',
            fixSuggestion:
                'Create an entitlements file and add com.apple.developer.associated-domains',
          ),
        );
      } else {
        results.add(
          VerificationResult(
            checkName: 'iOS Entitlements',
            status: VerificationStatus.success,
            message: 'Entitlements file found',
            details: {'path': entitlements.path},
          ),
        );

        // Check associated domains
        final associatedDomains = IosParser.parseEntitlements(entitlements);
        if (associatedDomains.isEmpty) {
          results.add(
            VerificationResult(
              checkName: 'iOS Associated Domains',
              status: VerificationStatus.error,
              message: 'No associated domains found in entitlements',
              fixSuggestion:
                  'Add com.apple.developer.associated-domains array to entitlements file',
            ),
          );
        } else {
          results.add(
            VerificationResult(
              checkName: 'iOS Associated Domains',
              status: VerificationStatus.success,
              message:
                  'Associated domains found: ${associatedDomains.join(", ")}',
            ),
          );
        }
      }
    }

    return results;
  }
}
