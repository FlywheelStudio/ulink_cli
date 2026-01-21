import '../models/platform_config.dart';
import '../models/project_config.dart';
import '../models/verification_result.dart';

/// Validator for cross-referencing local configs with ULink config
class ConfigValidator {
  /// Validate iOS configuration
  static List<VerificationResult> validateIos(
    PlatformConfig localConfig,
    ProjectConfig ulinkConfig,
  ) {
    final results = <VerificationResult>[];

    // Bundle Identifier match
    if (localConfig.bundleIdentifier != null &&
        ulinkConfig.iosBundleIdentifier != null) {
      if (localConfig.bundleIdentifier != ulinkConfig.iosBundleIdentifier) {
        results.add(
          VerificationResult(
            checkName: 'iOS Bundle Identifier Match',
            status: VerificationStatus.error,
            message: 'Bundle identifier mismatch',
            fixSuggestion:
                'Update ULink config: ${localConfig.bundleIdentifier}\n'
                'Or update Info.plist: ${ulinkConfig.iosBundleIdentifier}',
            details: {
              'local': localConfig.bundleIdentifier,
              'ulink': ulinkConfig.iosBundleIdentifier,
            },
          ),
        );
      } else {
        results.add(
          VerificationResult(
            checkName: 'iOS Bundle Identifier Match',
            status: VerificationStatus.success,
            message: 'Bundle identifier matches',
          ),
        );
      }
    } else {
      results.add(
        VerificationResult(
          checkName: 'iOS Bundle Identifier Match',
          status: VerificationStatus.warning,
          message:
              'Bundle identifier not found in local config or ULink config',
          fixSuggestion:
              'Ensure bundle identifier is set in both Info.plist and ULink dashboard',
        ),
      );
    }

    // URL Scheme match - use iOS-specific schemes for Flutter projects
    final schemesToCheck = localConfig.iosUrlSchemes.isNotEmpty
        ? localConfig.iosUrlSchemes
        : localConfig.urlSchemes;

    if (ulinkConfig.iosDeeplinkSchema != null &&
        ulinkConfig.iosDeeplinkSchema!.isNotEmpty) {
      final expectedScheme =
          ulinkConfig.iosDeeplinkSchema!.replaceAll('://', '').toLowerCase();
      final hasMatchingScheme = schemesToCheck.any(
        (scheme) => scheme.toLowerCase() == expectedScheme,
      );

      if (!hasMatchingScheme) {
        results.add(
          VerificationResult(
            checkName: 'iOS URL Scheme Match',
            status: VerificationStatus.error,
            message: 'URL scheme mismatch',
            fixSuggestion:
                'Add URL scheme "$expectedScheme" to Info.plist CFBundleURLSchemes\n'
                'Or update ULink config to match: ${schemesToCheck.isEmpty ? "(none found)" : schemesToCheck.join(", ")}',
            details: {'local': schemesToCheck, 'ulink': expectedScheme},
          ),
        );
      } else {
        // Check if there are extra schemes in local that don't match ULink
        final extraSchemes = schemesToCheck
            .where((scheme) => scheme.toLowerCase() != expectedScheme)
            .toList();

        if (extraSchemes.isNotEmpty) {
          results.add(
            VerificationResult(
              checkName: 'iOS URL Scheme Match',
              status: VerificationStatus.success,
              message: 'URL scheme matches (ULink: $expectedScheme)',
              details: {
                'matched': expectedScheme,
                'local': schemesToCheck,
                'ulink': expectedScheme,
              },
            ),
          );
          results.add(
            VerificationResult(
              checkName: 'iOS Extra URL Schemes',
              status: VerificationStatus.warning,
              message:
                  'Local has ${extraSchemes.length} extra URL scheme(s) not configured in ULink',
              fixSuggestion:
                  'These schemes are in your Info.plist but not in ULink config:\n${extraSchemes.join(", ")}\n'
                  'If these are intentional, you can ignore this warning. Otherwise, remove them or add "$expectedScheme" to ULink.',
              details: {
                'extraSchemes': extraSchemes,
                'ulinkScheme': expectedScheme,
              },
            ),
          );
        } else {
          results.add(
            VerificationResult(
              checkName: 'iOS URL Scheme Match',
              status: VerificationStatus.success,
              message: 'URL scheme matches',
            ),
          );
        }
      }
    } else if (schemesToCheck.isNotEmpty) {
      // Local has schemes but ULink doesn't have iOS deeplink schema configured
      results.add(
        VerificationResult(
          checkName: 'iOS URL Scheme Match',
          status: VerificationStatus.warning,
          message:
              'Local iOS has URL schemes but ULink iOS deeplink schema is not configured',
          fixSuggestion:
              'Configure iOS deeplink schema in ULink dashboard to: ${schemesToCheck.first}',
          details: {'local': schemesToCheck, 'ulink': '(not configured)'},
        ),
      );
    }

    // Associated Domains match - local needs to match at least ONE verified domain
    final iosVerifiedDomains = ulinkConfig.domains
        .where((d) => d.status == 'verified')
        .map((d) => d.host)
        .toList();

    final allUlinkDomains = ulinkConfig.domains.map((d) => d.host).toList();

    if (localConfig.associatedDomains.isNotEmpty) {
      // Check if any local domain matches a verified ULink domain
      final matchedVerifiedDomain = localConfig.associatedDomains.firstWhere(
        (localDomain) => iosVerifiedDomains.contains(localDomain),
        orElse: () => '',
      );

      if (matchedVerifiedDomain.isNotEmpty) {
        // Found a match with a verified domain
        results.add(
          VerificationResult(
            checkName: 'iOS Associated Domain Match',
            status: VerificationStatus.success,
            message: 'Associated domain matches verified ULink domain',
            details: {
              'matched': matchedVerifiedDomain,
              'local': localConfig.associatedDomains,
            },
          ),
        );
      } else {
        // No verified match, check if local domain exists in ULink but not verified
        final unverifiedMatch = localConfig.associatedDomains.firstWhere(
          (localDomain) => allUlinkDomains.contains(localDomain),
          orElse: () => '',
        );

        if (unverifiedMatch.isNotEmpty) {
          // Domain exists in ULink but is not verified
          final domainStatus = ulinkConfig.domains
              .firstWhere((d) => d.host == unverifiedMatch)
              .status;
          results.add(
            VerificationResult(
              checkName: 'iOS Associated Domain Match',
              status: VerificationStatus.error,
              message:
                  'Domain "$unverifiedMatch" exists in ULink but is not verified (status: $domainStatus)',
              fixSuggestion:
                  'Complete domain verification in ULink dashboard for "$unverifiedMatch"',
              details: {
                'local': localConfig.associatedDomains,
                'ulink': unverifiedMatch,
                'status': domainStatus,
              },
            ),
          );
        } else {
          // Local domain doesn't exist in ULink at all
          results.add(
            VerificationResult(
              checkName: 'iOS Associated Domain Match',
              status: VerificationStatus.error,
              message:
                  'Local domain "${localConfig.associatedDomains.first}" not found in ULink',
              fixSuggestion:
                  'Add domain "${localConfig.associatedDomains.first}" to ULink dashboard and verify it',
              details: {
                'local': localConfig.associatedDomains,
                'ulink': allUlinkDomains,
              },
            ),
          );
        }
      }
    } else if (iosVerifiedDomains.isNotEmpty) {
      // ULink has verified domains but local doesn't have any
      results.add(
        VerificationResult(
          checkName: 'iOS Associated Domain Match',
          status: VerificationStatus.warning,
          message: 'No associated domains in local config',
          fixSuggestion:
              'Add at least one verified domain to your entitlements file:\n${iosVerifiedDomains.map((d) => '  applinks:$d').join('\n')}',
          details: {
            'local': localConfig.associatedDomains,
            'ulink': iosVerifiedDomains,
          },
        ),
      );
    } else if (ulinkConfig.domains.isNotEmpty) {
      // ULink has domains but none are verified
      results.add(
        VerificationResult(
          checkName: 'iOS Associated Domain Match',
          status: VerificationStatus.warning,
          message: 'ULink has domains but none are verified',
          fixSuggestion:
              'Verify your domains in the ULink dashboard to enable Universal Links',
          details: {
            'local': localConfig.associatedDomains,
            'ulink': ulinkConfig.domains
                .map((d) => '${d.host} (${d.status})')
                .toList(),
          },
        ),
      );
    }

    // Team ID check and comparison
    if (ulinkConfig.iosTeamId == null || ulinkConfig.iosTeamId!.isEmpty) {
      results.add(
        VerificationResult(
          checkName: 'iOS Team ID',
          status: VerificationStatus.warning,
          message: 'Team ID not configured in ULink',
          fixSuggestion:
              'Add your Apple Team ID to ULink project configuration',
        ),
      );
    } else if (localConfig.teamId != null && localConfig.teamId!.isNotEmpty) {
      // Compare local Team ID with ULink Team ID
      if (localConfig.teamId != ulinkConfig.iosTeamId) {
        results.add(
          VerificationResult(
            checkName: 'iOS Team ID Match',
            status: VerificationStatus.error,
            message: 'Team ID mismatch',
            fixSuggestion: 'Update ULink Team ID to: ${localConfig.teamId}\n'
                'Or update your Xcode project to use: ${ulinkConfig.iosTeamId}',
            details: {
              'local': localConfig.teamId,
              'ulink': ulinkConfig.iosTeamId,
            },
          ),
        );
      } else {
        results.add(
          VerificationResult(
            checkName: 'iOS Team ID Match',
            status: VerificationStatus.success,
            message: 'Team ID matches',
          ),
        );
      }
    } else {
      results.add(
        VerificationResult(
          checkName: 'iOS Team ID',
          status: VerificationStatus.success,
          message: 'Team ID is configured in ULink',
          details: {'ulink': ulinkConfig.iosTeamId},
        ),
      );
    }

    return results;
  }

  /// Validate Android configuration
  static List<VerificationResult> validateAndroid(
    PlatformConfig localConfig,
    ProjectConfig ulinkConfig,
  ) {
    final results = <VerificationResult>[];

    // Package Name match
    if (localConfig.packageName != null &&
        ulinkConfig.androidPackageName != null) {
      if (localConfig.packageName != ulinkConfig.androidPackageName) {
        results.add(
          VerificationResult(
            checkName: 'Android Package Name Match',
            status: VerificationStatus.error,
            message: 'Package name mismatch',
            fixSuggestion: 'Update ULink config: ${localConfig.packageName}\n'
                'Or update AndroidManifest.xml: ${ulinkConfig.androidPackageName}',
            details: {
              'local': localConfig.packageName,
              'ulink': ulinkConfig.androidPackageName,
            },
          ),
        );
      } else {
        results.add(
          VerificationResult(
            checkName: 'Android Package Name Match',
            status: VerificationStatus.success,
            message: 'Package name matches',
          ),
        );
      }
    } else {
      results.add(
        VerificationResult(
          checkName: 'Android Package Name Match',
          status: VerificationStatus.warning,
          message: 'Package name not found in local config or ULink config',
          fixSuggestion:
              'Ensure package name is set in both AndroidManifest.xml and ULink dashboard',
        ),
      );
    }

    // URL Scheme match - use Android-specific schemes for Flutter projects
    // For pure Android projects, androidUrlSchemes should be set, but fallback to urlSchemes
    // For Flutter projects, androidUrlSchemes contains only Android schemes
    final androidSchemesToCheck = localConfig.androidUrlSchemes.isNotEmpty
        ? localConfig.androidUrlSchemes
        : (localConfig.urlSchemes.isNotEmpty
            ? localConfig.urlSchemes
            : <String>[]);

    if (ulinkConfig.androidDeeplinkSchema != null &&
        ulinkConfig.androidDeeplinkSchema!.isNotEmpty) {
      final expectedScheme = ulinkConfig.androidDeeplinkSchema!
          .replaceAll('://', '')
          .toLowerCase();

      final hasMatchingScheme = androidSchemesToCheck.any(
        (scheme) => scheme.toLowerCase() == expectedScheme,
      );

      if (!hasMatchingScheme) {
        // Provide more diagnostic info
        final diagnosticMessage = androidSchemesToCheck.isEmpty
            ? 'No URL schemes found in AndroidManifest.xml. Check that intent filters have:\n'
                '  - <action android:name="android.intent.action.VIEW" />\n'
                '  - <category android:name="android.intent.category.BROWSABLE" /> or DEFAULT\n'
                '  - <data android:scheme="..." />'
            : 'URL scheme mismatch';

        results.add(
          VerificationResult(
            checkName: 'Android URL Scheme Match',
            status: VerificationStatus.error,
            message: diagnosticMessage,
            fixSuggestion:
                'Add URL scheme "$expectedScheme" to AndroidManifest.xml intent filter\n'
                'Or update ULink config to match: ${androidSchemesToCheck.isEmpty ? "(none found)" : androidSchemesToCheck.join(", ")}',
            details: {
              'local': androidSchemesToCheck,
              'ulink': expectedScheme,
              'androidUrlSchemes': localConfig.androidUrlSchemes,
              'urlSchemes': localConfig.urlSchemes,
            },
          ),
        );
      } else {
        // Check if there are extra schemes in local that don't match ULink
        final extraSchemes = androidSchemesToCheck
            .where((scheme) => scheme.toLowerCase() != expectedScheme)
            .toList();

        if (extraSchemes.isNotEmpty) {
          results.add(
            VerificationResult(
              checkName: 'Android URL Scheme Match',
              status: VerificationStatus.success,
              message: 'URL scheme matches (ULink: $expectedScheme)',
              details: {
                'matched': expectedScheme,
                'local': androidSchemesToCheck,
                'ulink': expectedScheme,
              },
            ),
          );
          results.add(
            VerificationResult(
              checkName: 'Android Extra URL Schemes',
              status: VerificationStatus.warning,
              message:
                  'Local has ${extraSchemes.length} extra URL scheme(s) not configured in ULink',
              fixSuggestion:
                  'These schemes are in your AndroidManifest.xml but not in ULink config:\n${extraSchemes.join(", ")}\n'
                  'If these are intentional, you can ignore this warning. Otherwise, remove them or add "$expectedScheme" to ULink.',
              details: {
                'extraSchemes': extraSchemes,
                'ulinkScheme': expectedScheme,
              },
            ),
          );
        } else {
          results.add(
            VerificationResult(
              checkName: 'Android URL Scheme Match',
              status: VerificationStatus.success,
              message: 'URL scheme matches',
            ),
          );
        }
      }
    } else if (androidSchemesToCheck.isNotEmpty) {
      // Local has schemes but ULink doesn't have Android deeplink schema configured
      results.add(
        VerificationResult(
          checkName: 'Android URL Scheme Match',
          status: VerificationStatus.warning,
          message:
              'Local Android has URL schemes but ULink Android deeplink schema is not configured',
          fixSuggestion:
              'Configure Android deeplink schema in ULink dashboard to: ${androidSchemesToCheck.first}',
          details: {
            'local': androidSchemesToCheck,
            'ulink': '(not configured)'
          },
        ),
      );
    }

    // App Link Host match - local needs to match at least ONE verified domain
    final androidVerifiedDomains = ulinkConfig.domains
        .where((d) => d.status == 'verified')
        .map((d) => d.host)
        .toList();

    final allAndroidUlinkDomains =
        ulinkConfig.domains.map((d) => d.host).toList();

    if (localConfig.appLinkHosts.isNotEmpty) {
      // Check if any local host matches a verified ULink domain
      final matchedVerifiedHost = localConfig.appLinkHosts.firstWhere(
        (localHost) => androidVerifiedDomains.contains(localHost),
        orElse: () => '',
      );

      if (matchedVerifiedHost.isNotEmpty) {
        // Found a match with a verified domain
        results.add(
          VerificationResult(
            checkName: 'Android App Link Host Match',
            status: VerificationStatus.success,
            message: 'App Link host matches verified ULink domain',
            details: {
              'matched': matchedVerifiedHost,
              'local': localConfig.appLinkHosts,
            },
          ),
        );
      } else {
        // No verified match, check if local host exists in ULink but not verified
        final unverifiedMatch = localConfig.appLinkHosts.firstWhere(
          (localHost) => allAndroidUlinkDomains.contains(localHost),
          orElse: () => '',
        );

        if (unverifiedMatch.isNotEmpty) {
          // Host exists in ULink but is not verified
          final domainStatus = ulinkConfig.domains
              .firstWhere((d) => d.host == unverifiedMatch)
              .status;
          results.add(
            VerificationResult(
              checkName: 'Android App Link Host Match',
              status: VerificationStatus.error,
              message:
                  'Domain "$unverifiedMatch" exists in ULink but is not verified (status: $domainStatus)',
              fixSuggestion:
                  'Complete domain verification in ULink dashboard for "$unverifiedMatch"',
              details: {
                'local': localConfig.appLinkHosts,
                'ulink': unverifiedMatch,
                'status': domainStatus,
              },
            ),
          );
        } else {
          // Local host doesn't exist in ULink at all
          results.add(
            VerificationResult(
              checkName: 'Android App Link Host Match',
              status: VerificationStatus.error,
              message:
                  'Local host "${localConfig.appLinkHosts.first}" not found in ULink',
              fixSuggestion:
                  'Add domain "${localConfig.appLinkHosts.first}" to ULink dashboard and verify it',
              details: {
                'local': localConfig.appLinkHosts,
                'ulink': allAndroidUlinkDomains,
              },
            ),
          );
        }
      }
    } else if (androidVerifiedDomains.isNotEmpty) {
      // ULink has verified domains but local doesn't have any
      results.add(
        VerificationResult(
          checkName: 'Android App Link Host Match',
          status: VerificationStatus.warning,
          message: 'No App Link hosts in local config',
          fixSuggestion:
              'Add at least one verified domain to your AndroidManifest.xml:\n${androidVerifiedDomains.map((h) => '  android:host="$h"').join('\n')}',
          details: {
            'local': localConfig.appLinkHosts,
            'ulink': androidVerifiedDomains,
          },
        ),
      );
    } else if (ulinkConfig.domains.isNotEmpty) {
      // ULink has domains but none are verified
      results.add(
        VerificationResult(
          checkName: 'Android App Link Host Match',
          status: VerificationStatus.warning,
          message: 'ULink has domains but none are verified',
          fixSuggestion:
              'Verify your domains in the ULink dashboard to enable App Links',
          details: {
            'local': localConfig.appLinkHosts,
            'ulink': ulinkConfig.domains
                .map((d) => '${d.host} (${d.status})')
                .toList(),
          },
        ),
      );
    }

    // SHA-256 Fingerprints check
    if (ulinkConfig.androidSha256Fingerprints.isEmpty) {
      results.add(
        VerificationResult(
          checkName: 'Android SHA-256 Fingerprints',
          status: VerificationStatus.warning,
          message: 'SHA-256 fingerprints not configured in ULink',
          fixSuggestion:
              'Add your app signing key SHA-256 fingerprints to ULink project configuration',
        ),
      );
    } else {
      results.add(
        VerificationResult(
          checkName: 'Android SHA-256 Fingerprints',
          status: VerificationStatus.success,
          message:
              'SHA-256 fingerprints are configured (${ulinkConfig.androidSha256Fingerprints.length} fingerprints)',
        ),
      );
    }

    return results;
  }
}
