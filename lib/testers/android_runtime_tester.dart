import 'dart:io';
import '../models/verification_result.dart';

/// Runtime tester for Android App Links
class AndroidRuntimeTester {
  /// Check if ADB is available
  static Future<bool> isAdbAvailable() async {
    try {
      final result = await Process.run('adb', ['version']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// Check if device is connected
  static Future<bool> isDeviceConnected() async {
    try {
      final result = await Process.run('adb', ['devices']);
      if (result.exitCode == 0) {
        final output = result.stdout as String;
        // Check if there's a device listed (not just "List of devices attached")
        final lines = output.split('\n');
        return lines.any(
          (line) =>
              line.trim().isNotEmpty &&
              !line.contains('List of devices') &&
              !line.contains('daemon'),
        );
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Get app links verification status
  static Future<VerificationResult> getAppLinksStatus(
    String packageName,
  ) async {
    if (!await isAdbAvailable()) {
      return VerificationResult(
        checkName: 'Android Runtime Test - App Links Status',
        status: VerificationStatus.skipped,
        message: 'ADB not available',
        fixSuggestion:
            'Install Android SDK Platform Tools and ensure adb is in PATH',
      );
    }

    if (!await isDeviceConnected()) {
      return VerificationResult(
        checkName: 'Android Runtime Test - App Links Status',
        status: VerificationStatus.skipped,
        message: 'No Android device/emulator connected',
        fixSuggestion: 'Connect an Android device or start an emulator',
      );
    }

    try {
      // Check Android version first
      final sdkVersionResult = await Process.run('adb', [
        'shell',
        'getprop',
        'ro.build.version.sdk',
      ]);

      final sdkVersion =
          int.tryParse((sdkVersionResult.stdout as String).trim()) ?? 0;
      final supportsGetAppLinks = sdkVersion >= 31; // Android 12+

      if (!supportsGetAppLinks) {
        // For Android < 12, check if app links are configured using dumpsys
        // First check if app has domain URLs configured
        final dumpsysResult = await Process.run('adb', [
          'shell',
          'dumpsys',
          'package',
          packageName,
        ]);

        final hasDomainUrls =
            (dumpsysResult.stdout as String).contains('HAS_DOMAIN_URLS');

        if (!hasDomainUrls) {
          return VerificationResult(
            checkName: 'Android Runtime Test - App Links Status',
            status: VerificationStatus.warning,
            message: 'App links not configured in AndroidManifest.xml',
            fixSuggestion:
                'Add intent filters with android:autoVerify="true" to AndroidManifest.xml',
            details: {'packageName': packageName},
          );
        }

        // App has domain URLs configured, check user selection preference
        final result = await Process.run('adb', [
          'shell',
          'pm',
          'get-app-link',
          packageName,
        ]);

        if (result.exitCode == 0) {
          final output = result.stdout as String;
          // Parse the output (format: "always", "ask", "never", or "undefined")
          final status = output.trim().toLowerCase();

          if (status == 'always') {
            return VerificationResult(
              checkName: 'Android Runtime Test - App Links Status',
              status: VerificationStatus.success,
              message: 'App links enabled. User selection: always open in app',
              details: {
                'packageName': packageName,
                'userSelection': status,
                'androidVersion':
                    'Android ${sdkVersion < 21 ? "Lollipop" : sdkVersion < 23 ? "Marshmallow" : sdkVersion < 26 ? "Nougat" : sdkVersion < 28 ? "Oreo" : sdkVersion < 29 ? "Pie" : sdkVersion < 30 ? "10" : sdkVersion < 31 ? "11" : "12+"}',
              },
            );
          } else if (status == 'ask') {
            return VerificationResult(
              checkName: 'Android Runtime Test - App Links Status',
              status: VerificationStatus.warning,
              message: 'App links configured but user will be asked each time',
              fixSuggestion:
                  'Run: adb shell pm set-app-link --package $packageName always',
              details: {'packageName': packageName, 'userSelection': status},
            );
          } else if (status == 'undefined') {
            // On Android < 12, "undefined" means no explicit user preference is set
            // This is normal - app links still work based on domain verification
            // The pm get-app-link command only tracks explicit user preferences, not verification status
            return VerificationResult(
              checkName: 'Android Runtime Test - App Links Status',
              status: VerificationStatus.success,
              message:
                  'App links configured. On Android ${sdkVersion < 30 ? "10" : "11"}, links will open in app based on domain verification.',
              details: {
                'packageName': packageName,
                'userSelection': status,
                'appLinksConfigured': true,
                'androidSdkVersion': sdkVersion,
                'note':
                    'On Android < 12, pm get-app-link only tracks explicit user preferences. App links work based on domain verification.',
              },
            );
          } else {
            return VerificationResult(
              checkName: 'Android Runtime Test - App Links Status',
              status: VerificationStatus.warning,
              message: 'App links user selection: $status',
              fixSuggestion:
                  'Run: adb shell pm set-app-link --package $packageName always',
              details: {'packageName': packageName, 'userSelection': status},
            );
          }
        }
      }

      // For Android 12+, use get-app-links (plural)
      final result = await Process.run('adb', [
        'shell',
        'pm',
        'get-app-links',
        packageName,
      ]);

      if (result.exitCode != 0) {
        final errorMsg = (result.stderr as String).trim();
        final stdoutMsg = (result.stdout as String).trim();
        final fullError = errorMsg.isNotEmpty
            ? errorMsg
            : (stdoutMsg.isNotEmpty ? stdoutMsg : 'Unknown error');

        // Check if app is installed
        final installCheck = await Process.run('adb', [
          'shell',
          'pm',
          'list',
          'packages',
          packageName,
        ]);

        final isInstalled = installCheck.exitCode == 0 &&
            (installCheck.stdout as String).contains('package:$packageName');

        if (!isInstalled) {
          return VerificationResult(
            checkName: 'Android Runtime Test - App Links Status',
            status: VerificationStatus.error,
            message: 'App not installed on device. Package: $packageName',
            fixSuggestion: 'Install the app on the device/emulator first',
          );
        }

        return VerificationResult(
          checkName: 'Android Runtime Test - App Links Status',
          status: VerificationStatus.warning,
          message: 'Failed to get app links status: $fullError',
          fixSuggestion:
              'The app may not have app links configured. Check AndroidManifest.xml for intent filters.',
          details: {
            'packageName': packageName,
            'error': fullError,
            'exitCode': result.exitCode.toString(),
          },
        );
      }

      final output = result.stdout as String;

      // Parse output to find verification status
      // Format: "com.example.app:\n  ID: ...\n  Signatures: ...\n  Domain verification state:\n    example.com: verified"
      final lines = output.split('\n');
      final statusMap = <String, String>{};
      String? currentDomain;

      for (final line in lines) {
        if (line.contains(':')) {
          final parts = line.split(':');
          if (parts.length >= 2) {
            final key = parts[0].trim();
            final value = parts.sublist(1).join(':').trim();

            if (key.contains('Domain verification state') ||
                key.contains('Verification state')) {
              // Next lines will contain domain statuses
              currentDomain = null;
            } else if (currentDomain != null || key.contains('.')) {
              // This might be a domain
              if (key.contains('.')) {
                currentDomain = key;
                statusMap[currentDomain] = value;
              }
            }
          }
        }
      }

      // Check for verified status
      final verifiedDomains = statusMap.entries
          .where((e) => e.value.toLowerCase().contains('verified'))
          .map((e) => e.key)
          .toList();

      if (verifiedDomains.isNotEmpty) {
        return VerificationResult(
          checkName: 'Android Runtime Test - App Links Status',
          status: VerificationStatus.success,
          message:
              'App links verified for domains: ${verifiedDomains.join(", ")}',
          details: {
            'packageName': packageName,
            'verifiedDomains': verifiedDomains,
            'allStatuses': statusMap,
          },
        );
      } else {
        final allStatuses = statusMap.values.join(', ');
        return VerificationResult(
          checkName: 'Android Runtime Test - App Links Status',
          status: VerificationStatus.warning,
          message: 'App links not verified. Status: $allStatuses',
          fixSuggestion:
              'Run: adb shell pm verify-app-links --re-verify $packageName\n'
              'Then check the status again',
          details: {'packageName': packageName, 'statuses': statusMap},
        );
      }
    } catch (e) {
      return VerificationResult(
        checkName: 'Android Runtime Test - App Links Status',
        status: VerificationStatus.error,
        message: 'Error checking app links status: $e',
        fixSuggestion: 'Ensure ADB is working and device is connected',
      );
    }
  }

  /// Force re-verification of app links
  static Future<VerificationResult> reVerifyAppLinks(String packageName) async {
    if (!await isAdbAvailable()) {
      return VerificationResult(
        checkName: 'Android Runtime Test - Re-verify App Links',
        status: VerificationStatus.skipped,
        message: 'ADB not available',
      );
    }

    if (!await isDeviceConnected()) {
      return VerificationResult(
        checkName: 'Android Runtime Test - Re-verify App Links',
        status: VerificationStatus.skipped,
        message: 'No Android device connected',
      );
    }

    try {
      final result = await Process.run('adb', [
        'shell',
        'pm',
        'verify-app-links',
        '--re-verify',
        packageName,
      ]);

      if (result.exitCode == 0) {
        return VerificationResult(
          checkName: 'Android Runtime Test - Re-verify App Links',
          status: VerificationStatus.success,
          message: 'App links re-verification initiated',
          fixSuggestion: 'Wait a few seconds, then check status again',
        );
      } else {
        return VerificationResult(
          checkName: 'Android Runtime Test - Re-verify App Links',
          status: VerificationStatus.error,
          message: 'Failed to re-verify app links: ${result.stderr}',
        );
      }
    } catch (e) {
      return VerificationResult(
        checkName: 'Android Runtime Test - Re-verify App Links',
        status: VerificationStatus.error,
        message: 'Error re-verifying app links: $e',
      );
    }
  }

  /// Test opening an app link
  static Future<VerificationResult> testAppLink(
    String url,
    String? packageName,
  ) async {
    if (!await isAdbAvailable()) {
      return VerificationResult(
        checkName: 'Android Runtime Test - App Link',
        status: VerificationStatus.skipped,
        message: 'ADB not available',
      );
    }

    if (!await isDeviceConnected()) {
      return VerificationResult(
        checkName: 'Android Runtime Test - App Link',
        status: VerificationStatus.skipped,
        message: 'No Android device connected',
      );
    }

    try {
      final result = await Process.run('adb', [
        'shell',
        'am',
        'start',
        '-a',
        'android.intent.action.VIEW',
        '-c',
        'android.intent.category.BROWSABLE',
        '-d',
        url,
      ]);

      if (result.exitCode == 0) {
        return VerificationResult(
          checkName: 'Android Runtime Test - App Link',
          status: VerificationStatus.success,
          message: 'Successfully opened app link',
          details: {'url': url},
        );
      } else {
        return VerificationResult(
          checkName: 'Android Runtime Test - App Link',
          status: VerificationStatus.warning,
          message: 'Failed to open app link: ${result.stderr}',
          fixSuggestion:
              'Ensure the app is installed and app links are configured',
          details: {'url': url, 'error': result.stderr},
        );
      }
    } catch (e) {
      return VerificationResult(
        checkName: 'Android Runtime Test - App Link',
        status: VerificationStatus.error,
        message: 'Error testing app link: $e',
        fixSuggestion: 'Check that ADB is working and device is connected',
      );
    }
  }
}
