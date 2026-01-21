import 'dart:async';
import 'dart:io';
import '../models/verification_result.dart';

/// Runtime tester for iOS Universal Links
class IosRuntimeTester {
  /// Check if iOS simulator is available
  static Future<bool> isSimulatorAvailable() async {
    try {
      final result = await Process.run('xcrun', ['simctl', 'list', 'devices']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// Get booted simulator ID
  static Future<String?> getBootedSimulator() async {
    try {
      final result = await Process.run('xcrun', [
        'simctl',
        'list',
        'devices',
        'booted',
      ]);
      if (result.exitCode == 0) {
        final output = result.stdout as String;
        // Parse output to find booted device
        final lines = output.split('\n');
        for (final line in lines) {
          if (line.contains('Booted')) {
            // Extract device ID (format: "    iPhone 15 Pro (ABC12345-6789-...) (Booted)")
            final match = RegExp(r'\(([A-F0-9-]+)\)').firstMatch(line);
            if (match != null) {
              return match.group(1);
            }
          }
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Check if app is installed on simulator
  static Future<bool> isAppInstalled(
    String bundleIdentifier,
    String? simulatorId,
  ) async {
    try {
      final simId = simulatorId ?? 'booted';
      final result = await Process.run('xcrun', [
        'simctl',
        'get_app_container',
        simId,
        bundleIdentifier,
      ]);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// Check domain association status using swcutil_ctl (iOS 16+)
  /// This is the proper way to check if a domain is associated with an app
  static Future<VerificationResult> checkDomainAssociationStatus(
    String domain,
    String? bundleIdentifier,
  ) async {
    // Check if simulator is available
    if (!await isSimulatorAvailable()) {
      return VerificationResult(
        checkName: 'iOS Runtime Test - Domain Association',
        status: VerificationStatus.skipped,
        message: 'iOS Simulator not available (xcrun simctl not found)',
        fixSuggestion: 'Install Xcode and ensure xcrun is available',
      );
    }

    // Check if a simulator is booted
    final bootedSim = await getBootedSimulator();
    if (bootedSim == null) {
      return VerificationResult(
        checkName: 'iOS Runtime Test - Domain Association',
        status: VerificationStatus.skipped,
        message: 'No booted iOS simulator found',
        fixSuggestion: 'Boot an iOS simulator: xcrun simctl boot <device-id>',
      );
    }

    if (bundleIdentifier == null || bundleIdentifier.isEmpty) {
      return VerificationResult(
        checkName: 'iOS Runtime Test - Domain Association',
        status: VerificationStatus.skipped,
        message: 'Bundle identifier not found',
        fixSuggestion: 'Ensure bundle identifier is configured in Info.plist',
      );
    }

    // Check if app is installed
    final appInstalled = await isAppInstalled(bundleIdentifier, bootedSim);
    if (!appInstalled) {
      return VerificationResult(
        checkName: 'iOS Runtime Test - Domain Association',
        status: VerificationStatus.warning,
        message: 'App not installed on simulator',
        fixSuggestion: 'Install the app on the simulator first:\n'
            '  xcrun simctl install booted <path-to-app.app>\n'
            'Or build and run the app from Xcode',
        details: {'bundleIdentifier': bundleIdentifier, 'simulator': bootedSim},
      );
    }

    try {
      // Use swcutil_ctl to check domain association (iOS 16+)
      // This command queries the system for domain association status
      final result = await Process.run('xcrun', [
        'simctl',
        'spawn',
        bootedSim,
        'swcutil_ctl',
        'status',
        domain,
      ]);

      if (result.exitCode == 0) {
        final output = result.stdout as String;
        // Parse output to check association status
        if (output.contains('associated') ||
            output.contains('accepted') ||
            output.contains(bundleIdentifier)) {
          return VerificationResult(
            checkName: 'iOS Runtime Test - Domain Association',
            status: VerificationStatus.success,
            message: 'Domain is associated with app',
            details: {
              'domain': domain,
              'bundleIdentifier': bundleIdentifier,
              'simulator': bootedSim,
            },
          );
        } else if (output.contains('denied') ||
            output.contains('not associated')) {
          return VerificationResult(
            checkName: 'iOS Runtime Test - Domain Association',
            status: VerificationStatus.error,
            message: 'Domain association denied or not found',
            fixSuggestion: 'Check that:\n'
                '  1. AASA file is accessible: https://$domain/.well-known/apple-app-site-association\n'
                '  2. App entitlements include the domain\n'
                '  3. Domain is verified in ULink dashboard',
            details: {
              'domain': domain,
              'bundleIdentifier': bundleIdentifier,
              'output': output,
            },
          );
        }
      }

      // Fallback: Check system logs for domain association
      return await _checkDomainAssociationFromLogs(domain, bundleIdentifier);
    } catch (e) {
      // swcutil_ctl might not be available on older iOS versions
      // Fall back to log checking
      return await _checkDomainAssociationFromLogs(domain, bundleIdentifier);
    }
  }

  /// Check domain association from system logs
  static Future<VerificationResult> _checkDomainAssociationFromLogs(
    String domain,
    String? bundleIdentifier,
  ) async {
    final bootedSim = await getBootedSimulator();
    if (bootedSim == null) {
      return VerificationResult(
        checkName: 'iOS Runtime Test - Domain Association',
        status: VerificationStatus.skipped,
        message: 'No booted iOS simulator found',
      );
    }

    try {
      // Query system logs for domain association events
      final result = await Process.run('xcrun', [
        'simctl',
        'spawn',
        bootedSim,
        'log',
        'show',
        '--predicate',
        'subsystem == "com.apple.applinks" AND eventMessage contains "$domain"',
        '--last',
        '1m',
      ]);

      if (result.exitCode == 0) {
        final output = result.stdout as String;
        if (output.contains('accepted') || output.contains('associated')) {
          return VerificationResult(
            checkName: 'iOS Runtime Test - Domain Association',
            status: VerificationStatus.success,
            message: 'Domain association found in system logs',
            details: {'domain': domain, 'bundleIdentifier': bundleIdentifier},
          );
        } else if (output.contains('denied')) {
          return VerificationResult(
            checkName: 'iOS Runtime Test - Domain Association',
            status: VerificationStatus.error,
            message: 'Domain association denied',
            fixSuggestion: 'Check AASA file accessibility and app entitlements',
            details: {'domain': domain},
          );
        }
      }

      // If no clear status, provide manual verification instructions
      return VerificationResult(
        checkName: 'iOS Runtime Test - Domain Association',
        status: VerificationStatus.warning,
        message: 'Could not determine domain association status automatically',
        fixSuggestion: 'Manually verify domain association:\n'
            '  1. Open the app on the simulator\n'
            '  2. Open Safari and navigate to: https://$domain\n'
            '  3. Long-press a link - if it shows "Open in [Your App]", association works\n'
            '  4. Or check logs: xcrun simctl spawn booted log stream --predicate \'subsystem == "com.apple.applinks"\'',
        details: {'domain': domain, 'bundleIdentifier': bundleIdentifier},
      );
    } catch (e) {
      return VerificationResult(
        checkName: 'iOS Runtime Test - Domain Association',
        status: VerificationStatus.warning,
        message: 'Could not check domain association: $e',
        fixSuggestion:
            'Manually verify by opening a link in Safari and checking if it opens the app',
        details: {'domain': domain},
      );
    }
  }
}
