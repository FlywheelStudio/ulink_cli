import 'package:test/test.dart';
import 'package:ulink_cli/models/platform_config.dart';
import 'package:ulink_cli/models/project_config.dart';
import 'package:ulink_cli/models/verification_result.dart';
import 'package:ulink_cli/validators/config_validator.dart';

void main() {
  group('ConfigValidator', () {
    group('validateIos', () {
      group('Bundle Identifier', () {
        test('should return success when bundle identifiers match', () {
          final localConfig = PlatformConfig(
            projectType: ProjectType.ios,
            bundleIdentifier: 'com.example.app',
          );
          final ulinkConfig = ProjectConfig(
            projectId: 'test-project',
            iosBundleIdentifier: 'com.example.app',
          );

          final results = ConfigValidator.validateIos(localConfig, ulinkConfig);

          final bundleIdResult = results.firstWhere(
            (r) => r.checkName == 'iOS Bundle Identifier Match',
          );
          expect(bundleIdResult.status, VerificationStatus.success);
          expect(bundleIdResult.message, 'Bundle identifier matches');
        });

        test('should return error when bundle identifiers mismatch', () {
          final localConfig = PlatformConfig(
            projectType: ProjectType.ios,
            bundleIdentifier: 'com.example.app',
          );
          final ulinkConfig = ProjectConfig(
            projectId: 'test-project',
            iosBundleIdentifier: 'com.example.different',
          );

          final results = ConfigValidator.validateIos(localConfig, ulinkConfig);

          final bundleIdResult = results.firstWhere(
            (r) => r.checkName == 'iOS Bundle Identifier Match',
          );
          expect(bundleIdResult.status, VerificationStatus.error);
          expect(bundleIdResult.message, 'Bundle identifier mismatch');
          expect(bundleIdResult.details?['local'], 'com.example.app');
          expect(bundleIdResult.details?['ulink'], 'com.example.different');
        });

        test('should return warning when local bundle identifier is null', () {
          final localConfig = PlatformConfig(
            projectType: ProjectType.ios,
            bundleIdentifier: null,
          );
          final ulinkConfig = ProjectConfig(
            projectId: 'test-project',
            iosBundleIdentifier: 'com.example.app',
          );

          final results = ConfigValidator.validateIos(localConfig, ulinkConfig);

          final bundleIdResult = results.firstWhere(
            (r) => r.checkName == 'iOS Bundle Identifier Match',
          );
          expect(bundleIdResult.status, VerificationStatus.warning);
        });

        test('should return warning when ulink bundle identifier is null', () {
          final localConfig = PlatformConfig(
            projectType: ProjectType.ios,
            bundleIdentifier: 'com.example.app',
          );
          final ulinkConfig = ProjectConfig(
            projectId: 'test-project',
            iosBundleIdentifier: null,
          );

          final results = ConfigValidator.validateIos(localConfig, ulinkConfig);

          final bundleIdResult = results.firstWhere(
            (r) => r.checkName == 'iOS Bundle Identifier Match',
          );
          expect(bundleIdResult.status, VerificationStatus.warning);
        });
      });

      group('URL Scheme', () {
        test('should return success when URL schemes match', () {
          final localConfig = PlatformConfig(
            projectType: ProjectType.ios,
            bundleIdentifier: 'com.example.app',
            urlSchemes: ['myapp'],
          );
          final ulinkConfig = ProjectConfig(
            projectId: 'test-project',
            iosBundleIdentifier: 'com.example.app',
            iosDeeplinkSchema: 'myapp://',
          );

          final results = ConfigValidator.validateIos(localConfig, ulinkConfig);

          final schemeResult = results.firstWhere(
            (r) => r.checkName == 'iOS URL Scheme Match',
          );
          expect(schemeResult.status, VerificationStatus.success);
        });

        test('should match URL schemes case-insensitively', () {
          final localConfig = PlatformConfig(
            projectType: ProjectType.ios,
            bundleIdentifier: 'com.example.app',
            urlSchemes: ['MyApp'],
          );
          final ulinkConfig = ProjectConfig(
            projectId: 'test-project',
            iosBundleIdentifier: 'com.example.app',
            iosDeeplinkSchema: 'myapp://',
          );

          final results = ConfigValidator.validateIos(localConfig, ulinkConfig);

          final schemeResult = results.firstWhere(
            (r) => r.checkName == 'iOS URL Scheme Match',
          );
          expect(schemeResult.status, VerificationStatus.success);
        });

        test('should return error when URL schemes do not match', () {
          final localConfig = PlatformConfig(
            projectType: ProjectType.ios,
            bundleIdentifier: 'com.example.app',
            urlSchemes: ['differentapp'],
          );
          final ulinkConfig = ProjectConfig(
            projectId: 'test-project',
            iosBundleIdentifier: 'com.example.app',
            iosDeeplinkSchema: 'myapp://',
          );

          final results = ConfigValidator.validateIos(localConfig, ulinkConfig);

          final schemeResult = results.firstWhere(
            (r) => r.checkName == 'iOS URL Scheme Match',
          );
          expect(schemeResult.status, VerificationStatus.error);
          expect(schemeResult.message, 'URL scheme mismatch');
        });

        test('should warn about extra URL schemes in local config', () {
          final localConfig = PlatformConfig(
            projectType: ProjectType.ios,
            bundleIdentifier: 'com.example.app',
            urlSchemes: ['myapp', 'myapp-dev', 'myapp-staging'],
          );
          final ulinkConfig = ProjectConfig(
            projectId: 'test-project',
            iosBundleIdentifier: 'com.example.app',
            iosDeeplinkSchema: 'myapp://',
          );

          final results = ConfigValidator.validateIos(localConfig, ulinkConfig);

          final extraSchemeResult = results.firstWhere(
            (r) => r.checkName == 'iOS Extra URL Schemes',
            orElse: () => VerificationResult(
              checkName: 'not found',
              status: VerificationStatus.skipped,
            ),
          );
          expect(extraSchemeResult.status, VerificationStatus.warning);
          expect(extraSchemeResult.details?['extraSchemes'], contains('myapp-dev'));
          expect(extraSchemeResult.details?['extraSchemes'], contains('myapp-staging'));
        });

        test('should warn when local has schemes but ULink has none configured', () {
          final localConfig = PlatformConfig(
            projectType: ProjectType.ios,
            bundleIdentifier: 'com.example.app',
            urlSchemes: ['myapp'],
          );
          final ulinkConfig = ProjectConfig(
            projectId: 'test-project',
            iosBundleIdentifier: 'com.example.app',
            iosDeeplinkSchema: null,
          );

          final results = ConfigValidator.validateIos(localConfig, ulinkConfig);

          final schemeResult = results.firstWhere(
            (r) => r.checkName == 'iOS URL Scheme Match',
          );
          expect(schemeResult.status, VerificationStatus.warning);
          expect(
            schemeResult.message,
            contains('URL schemes but ULink iOS deeplink schema is not configured'),
          );
        });

        test('should use iosUrlSchemes when available in Flutter projects', () {
          final localConfig = PlatformConfig(
            projectType: ProjectType.flutter,
            bundleIdentifier: 'com.example.app',
            urlSchemes: ['shared-scheme'],
            iosUrlSchemes: ['ios-specific-scheme'],
          );
          final ulinkConfig = ProjectConfig(
            projectId: 'test-project',
            iosBundleIdentifier: 'com.example.app',
            iosDeeplinkSchema: 'ios-specific-scheme://',
          );

          final results = ConfigValidator.validateIos(localConfig, ulinkConfig);

          final schemeResult = results.firstWhere(
            (r) => r.checkName == 'iOS URL Scheme Match',
          );
          expect(schemeResult.status, VerificationStatus.success);
        });
      });

      group('Associated Domains', () {
        test('should return success when local domain matches verified ULink domain', () {
          final localConfig = PlatformConfig(
            projectType: ProjectType.ios,
            bundleIdentifier: 'com.example.app',
            associatedDomains: ['example.com'],
          );
          final ulinkConfig = ProjectConfig(
            projectId: 'test-project',
            iosBundleIdentifier: 'com.example.app',
            domains: [
              DomainConfig(
                id: 'domain-1',
                host: 'example.com',
                status: 'verified',
              ),
            ],
          );

          final results = ConfigValidator.validateIos(localConfig, ulinkConfig);

          final domainResult = results.firstWhere(
            (r) => r.checkName == 'iOS Associated Domain Match',
          );
          expect(domainResult.status, VerificationStatus.success);
          expect(domainResult.message, contains('matches verified'));
        });

        test('should return error when local domain exists in ULink but is not verified', () {
          final localConfig = PlatformConfig(
            projectType: ProjectType.ios,
            bundleIdentifier: 'com.example.app',
            associatedDomains: ['pending.example.com'],
          );
          final ulinkConfig = ProjectConfig(
            projectId: 'test-project',
            iosBundleIdentifier: 'com.example.app',
            domains: [
              DomainConfig(
                id: 'domain-1',
                host: 'pending.example.com',
                status: 'pending',
              ),
            ],
          );

          final results = ConfigValidator.validateIos(localConfig, ulinkConfig);

          final domainResult = results.firstWhere(
            (r) => r.checkName == 'iOS Associated Domain Match',
          );
          expect(domainResult.status, VerificationStatus.error);
          expect(domainResult.message, contains('not verified'));
          expect(domainResult.details?['status'], 'pending');
        });

        test('should return error when local domain is not found in ULink', () {
          final localConfig = PlatformConfig(
            projectType: ProjectType.ios,
            bundleIdentifier: 'com.example.app',
            associatedDomains: ['unknown.example.com'],
          );
          final ulinkConfig = ProjectConfig(
            projectId: 'test-project',
            iosBundleIdentifier: 'com.example.app',
            domains: [
              DomainConfig(
                id: 'domain-1',
                host: 'different.example.com',
                status: 'verified',
              ),
            ],
          );

          final results = ConfigValidator.validateIos(localConfig, ulinkConfig);

          final domainResult = results.firstWhere(
            (r) => r.checkName == 'iOS Associated Domain Match',
          );
          expect(domainResult.status, VerificationStatus.error);
          expect(domainResult.message, contains('not found in ULink'));
        });

        test('should warn when ULink has verified domains but local has none', () {
          final localConfig = PlatformConfig(
            projectType: ProjectType.ios,
            bundleIdentifier: 'com.example.app',
            associatedDomains: [],
          );
          final ulinkConfig = ProjectConfig(
            projectId: 'test-project',
            iosBundleIdentifier: 'com.example.app',
            domains: [
              DomainConfig(
                id: 'domain-1',
                host: 'example.com',
                status: 'verified',
              ),
            ],
          );

          final results = ConfigValidator.validateIos(localConfig, ulinkConfig);

          final domainResult = results.firstWhere(
            (r) => r.checkName == 'iOS Associated Domain Match',
          );
          expect(domainResult.status, VerificationStatus.warning);
          expect(domainResult.message, contains('No associated domains'));
        });

        test('should warn when ULink has domains but none are verified', () {
          final localConfig = PlatformConfig(
            projectType: ProjectType.ios,
            bundleIdentifier: 'com.example.app',
            associatedDomains: [],
          );
          final ulinkConfig = ProjectConfig(
            projectId: 'test-project',
            iosBundleIdentifier: 'com.example.app',
            domains: [
              DomainConfig(
                id: 'domain-1',
                host: 'example.com',
                status: 'pending',
              ),
            ],
          );

          final results = ConfigValidator.validateIos(localConfig, ulinkConfig);

          final domainResult = results.firstWhere(
            (r) => r.checkName == 'iOS Associated Domain Match',
          );
          expect(domainResult.status, VerificationStatus.warning);
          expect(domainResult.message, contains('none are verified'));
        });
      });

      group('Team ID', () {
        test('should return success when team IDs match', () {
          final localConfig = PlatformConfig(
            projectType: ProjectType.ios,
            bundleIdentifier: 'com.example.app',
            teamId: 'ABC123DEFG',
          );
          final ulinkConfig = ProjectConfig(
            projectId: 'test-project',
            iosBundleIdentifier: 'com.example.app',
            iosTeamId: 'ABC123DEFG',
          );

          final results = ConfigValidator.validateIos(localConfig, ulinkConfig);

          final teamIdResult = results.firstWhere(
            (r) => r.checkName == 'iOS Team ID Match',
          );
          expect(teamIdResult.status, VerificationStatus.success);
          expect(teamIdResult.message, 'Team ID matches');
        });

        test('should return error when team IDs mismatch', () {
          final localConfig = PlatformConfig(
            projectType: ProjectType.ios,
            bundleIdentifier: 'com.example.app',
            teamId: 'ABC123DEFG',
          );
          final ulinkConfig = ProjectConfig(
            projectId: 'test-project',
            iosBundleIdentifier: 'com.example.app',
            iosTeamId: 'DIFFERENT1',
          );

          final results = ConfigValidator.validateIos(localConfig, ulinkConfig);

          final teamIdResult = results.firstWhere(
            (r) => r.checkName == 'iOS Team ID Match',
          );
          expect(teamIdResult.status, VerificationStatus.error);
          expect(teamIdResult.message, 'Team ID mismatch');
        });

        test('should warn when ULink team ID is not configured', () {
          final localConfig = PlatformConfig(
            projectType: ProjectType.ios,
            bundleIdentifier: 'com.example.app',
            teamId: 'ABC123DEFG',
          );
          final ulinkConfig = ProjectConfig(
            projectId: 'test-project',
            iosBundleIdentifier: 'com.example.app',
            iosTeamId: null,
          );

          final results = ConfigValidator.validateIos(localConfig, ulinkConfig);

          final teamIdResult = results.firstWhere(
            (r) => r.checkName == 'iOS Team ID',
          );
          expect(teamIdResult.status, VerificationStatus.warning);
          expect(teamIdResult.message, contains('not configured'));
        });

        test('should return success when ULink has team ID but local does not', () {
          final localConfig = PlatformConfig(
            projectType: ProjectType.ios,
            bundleIdentifier: 'com.example.app',
            teamId: null,
          );
          final ulinkConfig = ProjectConfig(
            projectId: 'test-project',
            iosBundleIdentifier: 'com.example.app',
            iosTeamId: 'ABC123DEFG',
          );

          final results = ConfigValidator.validateIos(localConfig, ulinkConfig);

          final teamIdResult = results.firstWhere(
            (r) => r.checkName == 'iOS Team ID',
          );
          expect(teamIdResult.status, VerificationStatus.success);
          expect(teamIdResult.message, contains('configured in ULink'));
        });
      });
    });

    group('validateAndroid', () {
      group('Package Name', () {
        test('should return success when package names match', () {
          final localConfig = PlatformConfig(
            projectType: ProjectType.android,
            packageName: 'com.example.app',
          );
          final ulinkConfig = ProjectConfig(
            projectId: 'test-project',
            androidPackageName: 'com.example.app',
          );

          final results = ConfigValidator.validateAndroid(localConfig, ulinkConfig);

          final packageResult = results.firstWhere(
            (r) => r.checkName == 'Android Package Name Match',
          );
          expect(packageResult.status, VerificationStatus.success);
          expect(packageResult.message, 'Package name matches');
        });

        test('should return error when package names mismatch', () {
          final localConfig = PlatformConfig(
            projectType: ProjectType.android,
            packageName: 'com.example.app',
          );
          final ulinkConfig = ProjectConfig(
            projectId: 'test-project',
            androidPackageName: 'com.example.different',
          );

          final results = ConfigValidator.validateAndroid(localConfig, ulinkConfig);

          final packageResult = results.firstWhere(
            (r) => r.checkName == 'Android Package Name Match',
          );
          expect(packageResult.status, VerificationStatus.error);
          expect(packageResult.message, 'Package name mismatch');
          expect(packageResult.details?['local'], 'com.example.app');
          expect(packageResult.details?['ulink'], 'com.example.different');
        });

        test('should return warning when package names are null', () {
          final localConfig = PlatformConfig(
            projectType: ProjectType.android,
            packageName: null,
          );
          final ulinkConfig = ProjectConfig(
            projectId: 'test-project',
            androidPackageName: null,
          );

          final results = ConfigValidator.validateAndroid(localConfig, ulinkConfig);

          final packageResult = results.firstWhere(
            (r) => r.checkName == 'Android Package Name Match',
          );
          expect(packageResult.status, VerificationStatus.warning);
        });
      });

      group('URL Scheme', () {
        test('should return success when URL schemes match', () {
          final localConfig = PlatformConfig(
            projectType: ProjectType.android,
            packageName: 'com.example.app',
            urlSchemes: ['myapp'],
          );
          final ulinkConfig = ProjectConfig(
            projectId: 'test-project',
            androidPackageName: 'com.example.app',
            androidDeeplinkSchema: 'myapp://',
          );

          final results = ConfigValidator.validateAndroid(localConfig, ulinkConfig);

          final schemeResult = results.firstWhere(
            (r) => r.checkName == 'Android URL Scheme Match',
          );
          expect(schemeResult.status, VerificationStatus.success);
        });

        test('should match URL schemes case-insensitively', () {
          final localConfig = PlatformConfig(
            projectType: ProjectType.android,
            packageName: 'com.example.app',
            urlSchemes: ['MYAPP'],
          );
          final ulinkConfig = ProjectConfig(
            projectId: 'test-project',
            androidPackageName: 'com.example.app',
            androidDeeplinkSchema: 'myapp://',
          );

          final results = ConfigValidator.validateAndroid(localConfig, ulinkConfig);

          final schemeResult = results.firstWhere(
            (r) => r.checkName == 'Android URL Scheme Match',
          );
          expect(schemeResult.status, VerificationStatus.success);
        });

        test('should return error when URL schemes do not match', () {
          final localConfig = PlatformConfig(
            projectType: ProjectType.android,
            packageName: 'com.example.app',
            urlSchemes: ['differentapp'],
          );
          final ulinkConfig = ProjectConfig(
            projectId: 'test-project',
            androidPackageName: 'com.example.app',
            androidDeeplinkSchema: 'myapp://',
          );

          final results = ConfigValidator.validateAndroid(localConfig, ulinkConfig);

          final schemeResult = results.firstWhere(
            (r) => r.checkName == 'Android URL Scheme Match',
          );
          expect(schemeResult.status, VerificationStatus.error);
        });

        test('should use androidUrlSchemes when available in Flutter projects', () {
          final localConfig = PlatformConfig(
            projectType: ProjectType.flutter,
            packageName: 'com.example.app',
            urlSchemes: ['shared-scheme'],
            androidUrlSchemes: ['android-specific-scheme'],
          );
          final ulinkConfig = ProjectConfig(
            projectId: 'test-project',
            androidPackageName: 'com.example.app',
            androidDeeplinkSchema: 'android-specific-scheme://',
          );

          final results = ConfigValidator.validateAndroid(localConfig, ulinkConfig);

          final schemeResult = results.firstWhere(
            (r) => r.checkName == 'Android URL Scheme Match',
          );
          expect(schemeResult.status, VerificationStatus.success);
        });

        test('should warn about extra URL schemes', () {
          final localConfig = PlatformConfig(
            projectType: ProjectType.android,
            packageName: 'com.example.app',
            urlSchemes: ['myapp', 'myapp-debug'],
          );
          final ulinkConfig = ProjectConfig(
            projectId: 'test-project',
            androidPackageName: 'com.example.app',
            androidDeeplinkSchema: 'myapp://',
          );

          final results = ConfigValidator.validateAndroid(localConfig, ulinkConfig);

          final extraResult = results.firstWhere(
            (r) => r.checkName == 'Android Extra URL Schemes',
            orElse: () => VerificationResult(
              checkName: 'not found',
              status: VerificationStatus.skipped,
            ),
          );
          expect(extraResult.status, VerificationStatus.warning);
        });
      });

      group('App Link Hosts', () {
        test('should return success when local host matches verified ULink domain', () {
          final localConfig = PlatformConfig(
            projectType: ProjectType.android,
            packageName: 'com.example.app',
            appLinkHosts: ['example.com'],
          );
          final ulinkConfig = ProjectConfig(
            projectId: 'test-project',
            androidPackageName: 'com.example.app',
            domains: [
              DomainConfig(
                id: 'domain-1',
                host: 'example.com',
                status: 'verified',
              ),
            ],
          );

          final results = ConfigValidator.validateAndroid(localConfig, ulinkConfig);

          final hostResult = results.firstWhere(
            (r) => r.checkName == 'Android App Link Host Match',
          );
          expect(hostResult.status, VerificationStatus.success);
          expect(hostResult.message, contains('matches verified'));
        });

        test('should return error when local host is not verified', () {
          final localConfig = PlatformConfig(
            projectType: ProjectType.android,
            packageName: 'com.example.app',
            appLinkHosts: ['example.com'],
          );
          final ulinkConfig = ProjectConfig(
            projectId: 'test-project',
            androidPackageName: 'com.example.app',
            domains: [
              DomainConfig(
                id: 'domain-1',
                host: 'example.com',
                status: 'pending',
              ),
            ],
          );

          final results = ConfigValidator.validateAndroid(localConfig, ulinkConfig);

          final hostResult = results.firstWhere(
            (r) => r.checkName == 'Android App Link Host Match',
          );
          expect(hostResult.status, VerificationStatus.error);
          expect(hostResult.message, contains('not verified'));
        });

        test('should return error when local host is not found in ULink', () {
          final localConfig = PlatformConfig(
            projectType: ProjectType.android,
            packageName: 'com.example.app',
            appLinkHosts: ['unknown.com'],
          );
          final ulinkConfig = ProjectConfig(
            projectId: 'test-project',
            androidPackageName: 'com.example.app',
            domains: [
              DomainConfig(
                id: 'domain-1',
                host: 'example.com',
                status: 'verified',
              ),
            ],
          );

          final results = ConfigValidator.validateAndroid(localConfig, ulinkConfig);

          final hostResult = results.firstWhere(
            (r) => r.checkName == 'Android App Link Host Match',
          );
          expect(hostResult.status, VerificationStatus.error);
          expect(hostResult.message, contains('not found in ULink'));
        });

        test('should warn when ULink has verified domains but local has none', () {
          final localConfig = PlatformConfig(
            projectType: ProjectType.android,
            packageName: 'com.example.app',
            appLinkHosts: [],
          );
          final ulinkConfig = ProjectConfig(
            projectId: 'test-project',
            androidPackageName: 'com.example.app',
            domains: [
              DomainConfig(
                id: 'domain-1',
                host: 'example.com',
                status: 'verified',
              ),
            ],
          );

          final results = ConfigValidator.validateAndroid(localConfig, ulinkConfig);

          final hostResult = results.firstWhere(
            (r) => r.checkName == 'Android App Link Host Match',
          );
          expect(hostResult.status, VerificationStatus.warning);
          expect(hostResult.message, contains('No App Link hosts'));
        });
      });

      group('SHA-256 Fingerprints', () {
        test('should return success when fingerprints are configured', () {
          final localConfig = PlatformConfig(
            projectType: ProjectType.android,
            packageName: 'com.example.app',
          );
          final ulinkConfig = ProjectConfig(
            projectId: 'test-project',
            androidPackageName: 'com.example.app',
            androidSha256Fingerprints: ['AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99'],
          );

          final results = ConfigValidator.validateAndroid(localConfig, ulinkConfig);

          final fingerprintResult = results.firstWhere(
            (r) => r.checkName == 'Android SHA-256 Fingerprints',
          );
          expect(fingerprintResult.status, VerificationStatus.success);
          expect(fingerprintResult.message, contains('1 fingerprints'));
        });

        test('should return warning when no fingerprints configured', () {
          final localConfig = PlatformConfig(
            projectType: ProjectType.android,
            packageName: 'com.example.app',
          );
          final ulinkConfig = ProjectConfig(
            projectId: 'test-project',
            androidPackageName: 'com.example.app',
            androidSha256Fingerprints: [],
          );

          final results = ConfigValidator.validateAndroid(localConfig, ulinkConfig);

          final fingerprintResult = results.firstWhere(
            (r) => r.checkName == 'Android SHA-256 Fingerprints',
          );
          expect(fingerprintResult.status, VerificationStatus.warning);
          expect(fingerprintResult.message, contains('not configured'));
        });

        test('should report correct count of multiple fingerprints', () {
          final localConfig = PlatformConfig(
            projectType: ProjectType.android,
            packageName: 'com.example.app',
          );
          final ulinkConfig = ProjectConfig(
            projectId: 'test-project',
            androidPackageName: 'com.example.app',
            androidSha256Fingerprints: [
              'AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99',
              'FF:EE:DD:CC:BB:AA:99:88:77:66:55:44:33:22:11:00:FF:EE:DD:CC:BB:AA:99:88:77:66:55:44:33:22:11:00',
            ],
          );

          final results = ConfigValidator.validateAndroid(localConfig, ulinkConfig);

          final fingerprintResult = results.firstWhere(
            (r) => r.checkName == 'Android SHA-256 Fingerprints',
          );
          expect(fingerprintResult.status, VerificationStatus.success);
          expect(fingerprintResult.message, contains('2 fingerprints'));
        });
      });
    });
  });
}
