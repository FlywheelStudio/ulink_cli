import '../models/verification_result.dart';
import '../models/platform_config.dart';
import '../parsers/android_parser.dart';
import '../parsers/project_detector.dart';

/// Validator for Android configuration files
class AndroidValidator {
  /// Validate Android project configuration
  static List<VerificationResult> validate(
    String projectPath,
    PlatformConfig? platformConfig,
  ) {
    final results = <VerificationResult>[];

    // Check AndroidManifest.xml
    final androidManifest = ProjectDetector.findAndroidManifest(
      projectPath,
      platformConfig?.projectType ?? ProjectType.android,
    );

    if (androidManifest == null) {
      results.add(
        VerificationResult(
          checkName: 'Android AndroidManifest.xml',
          status: VerificationStatus.error,
          message: 'AndroidManifest.xml not found',
          fixSuggestion:
              'Ensure AndroidManifest.xml exists in your Android project',
        ),
      );
      return results;
    }

    results.add(
      VerificationResult(
        checkName: 'Android AndroidManifest.xml',
        status: VerificationStatus.success,
        message: 'AndroidManifest.xml found',
        details: {'path': androidManifest.path},
      ),
    );

    if (platformConfig != null) {
      // Check package name
      if (platformConfig.packageName == null) {
        results.add(
          VerificationResult(
            checkName: 'Android Package Name',
            status: VerificationStatus.error,
            message: 'Package name not found in AndroidManifest.xml',
            fixSuggestion:
                'Add package attribute to <manifest> tag in AndroidManifest.xml',
          ),
        );
      } else {
        results.add(
          VerificationResult(
            checkName: 'Android Package Name',
            status: VerificationStatus.success,
            message: 'Package name found: ${platformConfig.packageName}',
          ),
        );
      }

      // Check URL schemes (custom schemes)
      if (platformConfig.urlSchemes.isEmpty) {
        results.add(
          VerificationResult(
            checkName: 'Android URL Schemes',
            status: VerificationStatus.warning,
            message: 'No custom URL schemes found in AndroidManifest.xml',
            fixSuggestion:
                'Add intent filter with custom scheme (e.g., myapp://)',
          ),
        );
      } else {
        results.add(
          VerificationResult(
            checkName: 'Android URL Schemes',
            status: VerificationStatus.success,
            message:
                'URL schemes found: ${platformConfig.urlSchemes.join(", ")}',
          ),
        );
      }

      // Check App Links (universal links)
      if (platformConfig.appLinkHosts.isEmpty) {
        results.add(
          VerificationResult(
            checkName: 'Android App Links',
            status: VerificationStatus.warning,
            message: 'No App Links (HTTPS) intent filters found',
            fixSuggestion:
                'Add intent filter with android:autoVerify="true" and android:scheme="https"',
          ),
        );
      } else {
        results.add(
          VerificationResult(
            checkName: 'Android App Links',
            status: VerificationStatus.success,
            message:
                'App link hosts found: ${platformConfig.appLinkHosts.join(", ")}',
          ),
        );
      }
    }

    return results;
  }
}
