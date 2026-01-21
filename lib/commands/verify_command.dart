import 'dart:io';
import 'package:path/path.dart' as path;
import '../models/verification_result.dart';
import '../models/platform_config.dart';
import '../models/project_config.dart';
import '../parsers/project_detector.dart';
import '../parsers/ios_parser.dart';
import '../parsers/android_parser.dart';
import '../parsers/flutter_parser.dart';
import '../validators/sdk_package_validator.dart';
import '../validators/ios_validator.dart';
import '../validators/android_validator.dart';
import '../validators/config_validator.dart';
import '../api/ulink_api_client.dart';
import '../testers/well_known_tester.dart';
import '../testers/ios_runtime_tester.dart';
import '../testers/android_runtime_tester.dart';
import '../reporters/report_generator.dart';
import '../auth/config_manager.dart';
import '../models/auth_config.dart';
import '../config/project_config_manager.dart';
import '../utils/progress_spinner.dart';
import '../utils/console_style.dart';

/// Command for verifying project configuration
class VerifyCommand {
  final String baseUrl;
  final bool verbose;

  VerifyCommand({
    required this.baseUrl,
    this.verbose = false,
  });

  /// Execute verification
  Future<void> execute(String projectPath) async {
    final absolutePath = path.absolute(projectPath);
    final dir = Directory(absolutePath);

    if (!dir.existsSync()) {
      stderr.writeln(ConsoleStyle.error('Error: Project path does not exist: $absolutePath'));
      exit(1);
    }

    // Step 1: Detect project type
    final detectSpinner = ProgressSpinner('Detecting project type...', verbose: verbose);
    detectSpinner.start();

    final projectType = ProjectDetector.detectProjectType(absolutePath);

    if (projectType == ProjectType.unknown) {
      detectSpinner.fail('Could not detect project type');
      stderr.writeln(ConsoleStyle.error(
        'Please run this command from your project root directory',
      ));
      exit(1);
    }

    detectSpinner.success('Detected ${projectType.name} project');

    final results = <VerificationResult>[];

    // 1. Validate SDK package installation
    final sdkSpinner = ProgressSpinner('Validating SDK package installation...', verbose: verbose);
    sdkSpinner.start();
    final sdkResults = SdkPackageValidator.validate(absolutePath, projectType);
    results.addAll(sdkResults);
    final sdkHasErrors = sdkResults.any((r) => r.status == VerificationStatus.error);
    if (sdkHasErrors) {
      sdkSpinner.warn('SDK validation completed with issues');
    } else {
      sdkSpinner.success('SDK packages validated');
    }

    // 2. Parse local configuration
    final parseSpinner = ProgressSpinner('Parsing local configuration...', verbose: verbose);
    parseSpinner.start();
    PlatformConfig? localConfig;

    if (projectType == ProjectType.flutter) {
      localConfig = FlutterParser.parseFlutterProject(absolutePath);
    } else if (projectType == ProjectType.ios) {
      final infoPlist = ProjectDetector.findInfoPlist(
        absolutePath,
        projectType,
      );
      final entitlements = ProjectDetector.findEntitlements(
        absolutePath,
        projectType,
      );

      if (infoPlist != null) {
        localConfig = IosParser.parseInfoPlist(infoPlist);
        if (entitlements != null && localConfig != null) {
          final domains = IosParser.parseEntitlements(entitlements);
          localConfig = PlatformConfig(
            projectType: localConfig.projectType,
            bundleIdentifier: localConfig.bundleIdentifier,
            urlSchemes: localConfig.urlSchemes,
            iosUrlSchemes: localConfig.iosUrlSchemes,
            androidUrlSchemes: localConfig.androidUrlSchemes,
            associatedDomains: domains,
            teamId: localConfig.teamId,
          );
        }
      }
    } else if (projectType == ProjectType.android) {
      final androidManifest = ProjectDetector.findAndroidManifest(
        absolutePath,
        projectType,
      );
      if (androidManifest != null) {
        localConfig = AndroidParser.parseAndroidManifest(androidManifest);
      }
    }

    if (localConfig == null) {
      parseSpinner.fail('Failed to parse configuration');
      results.add(
        VerificationResult(
          checkName: 'Local Configuration Parsing',
          status: VerificationStatus.error,
          message: 'Failed to parse local configuration files',
          fixSuggestion: 'Ensure project files are properly configured',
        ),
      );
    } else {
      parseSpinner.success('Configuration parsed');
      results.add(
        VerificationResult(
          checkName: 'Local Configuration Parsing',
          status: VerificationStatus.success,
          message: 'Successfully parsed local configuration',
        ),
      );
    }

    // 3. Validate local configuration files
    final validateSpinner = ProgressSpinner('Validating configuration files...', verbose: verbose);
    validateSpinner.start();
    if (projectType == ProjectType.flutter || projectType == ProjectType.ios) {
      results.addAll(IosValidator.validate(absolutePath, localConfig));
    }
    if (projectType == ProjectType.flutter ||
        projectType == ProjectType.android) {
      results.addAll(AndroidValidator.validate(absolutePath, localConfig));
    }
    validateSpinner.success('Configuration files validated');

    // 4. Fetch ULink configuration
    ProjectConfig? ulinkConfig;

    // Try to get project ID and credentials from various sources
    // Priority: 1. Directory config, 2. Global config
    String? effectiveProjectId;
    String? effectiveApiKey;

    // Load from directory config (per-directory project selection)
    final dirProjectId = ProjectConfigManager.loadProjectId(absolutePath);
    if (dirProjectId != null) {
      effectiveProjectId = dirProjectId;
      if (verbose) {
        print(ConsoleStyle.dim('Using project from directory config: $dirProjectId'));
      }
    }

    final config = ConfigManager.loadConfig();

    // API key can come from stored config or project-specific config
    if (config?.auth?.type == AuthType.apiKey) {
      effectiveApiKey = config!.auth!.apiKey;
    } else if (effectiveProjectId != null &&
        config?.projects.isNotEmpty == true) {
      // Try to find project-specific API key
      final project = config!.projects.firstWhere(
        (p) => p.projectId == effectiveProjectId,
        orElse: () => config.projects.first,
      );
      effectiveApiKey = project.apiKey;
    }

    // Check if we have credentials (either provided or from config)
    final hasCredentials = effectiveApiKey != null ||
        (config?.auth?.type == AuthType.jwt && config!.auth!.token != null);

    // If we have credentials but no project ID, try to fetch and select a project
    if (effectiveProjectId == null && hasCredentials) {
      final fetchProjectsSpinner = ProgressSpinner('Fetching your projects...', verbose: verbose);
      fetchProjectsSpinner.start();

      try {
        final apiClient = ULinkApiClient(
          baseUrl: baseUrl,
          apiKey: effectiveApiKey,
        );
        final projects = await apiClient.getProjects();

        if (projects.isEmpty) {
          fetchProjectsSpinner.warn('No projects found');
          results.add(
            VerificationResult(
              checkName: 'ULink API Connection',
              status: VerificationStatus.warning,
              message:
                  'No projects found. Create a project in the ULink dashboard first.',
              fixSuggestion: 'Visit https://ulink.ly to create a project',
            ),
          );
        } else if (projects.length == 1) {
          // Auto-select if only one project
          effectiveProjectId = projects.first.id;
          fetchProjectsSpinner.success('Auto-selected project: ${projects.first.name}');

          try {
            // Save to directory config (per-directory project selection)
            await ProjectConfigManager.saveProjectId(
              absolutePath,
              projects.first.id,
              projectName: projects.first.name,
            );
            if (verbose) {
              print(ConsoleStyle.success(
                  '✓ Saved project to directory config: ${path.join(absolutePath, '.ulink', 'project.json')}'));
            }
          } catch (e) {
            stderr.writeln(ConsoleStyle.warning(
                'Warning: Could not save project to directory config: $e'));
          }
        } else {
          // Stop spinner before showing selection menu
          fetchProjectsSpinner.success('Found ${projects.length} projects');

          // Show selection menu for multiple projects (always show - user input needed)
          print('\n${ConsoleStyle.info('Select a project:')}');
          for (int i = 0; i < projects.length; i++) {
            print('  ${i + 1}. ${projects[i].name} ${ConsoleStyle.dim('(${projects[i].id})')}');
          }
          stdout.write('\nEnter project number (1-${projects.length}): ');
          final input = stdin.readLineSync()?.trim();
          final selectedIndex = int.tryParse(input ?? '') ?? 0;

          if (selectedIndex < 1 || selectedIndex > projects.length) {
            results.add(
              VerificationResult(
                checkName: 'ULink API Connection',
                status: VerificationStatus.skipped,
                message: 'Invalid project selection',
                fixSuggestion:
                    'Run the command again and select a valid project',
              ),
            );
          } else {
            final selectedProject = projects[selectedIndex - 1];
            effectiveProjectId = selectedProject.id;
            print(ConsoleStyle.success('✓ Selected project: ${selectedProject.name}'));

            try {
              // Save to directory config (per-directory project selection)
              await ProjectConfigManager.saveProjectId(
                absolutePath,
                selectedProject.id,
                projectName: selectedProject.name,
              );
              if (verbose) {
                print(ConsoleStyle.success(
                    '✓ Saved project to directory config: ${path.join(absolutePath, '.ulink', 'project.json')}'));
              }
            } catch (e) {
              stderr.writeln(ConsoleStyle.warning(
                  'Warning: Could not save project to directory config: $e'));
            }
          }
        }
      } catch (e) {
        fetchProjectsSpinner.fail('Failed to fetch projects');
        results.add(
          VerificationResult(
            checkName: 'ULink API Connection',
            status: VerificationStatus.error,
            message: 'Failed to fetch projects: $e',
            fixSuggestion:
                'Check your credentials. Run "ulink login" to authenticate.',
          ),
        );
      }
    }

    // Now fetch project configuration if we have a project ID
    if (effectiveProjectId != null && hasCredentials) {
      final fetchConfigSpinner = ProgressSpinner('Fetching ULink configuration...', verbose: verbose);
      fetchConfigSpinner.start();

      try {
        final apiClient = ULinkApiClient(
          baseUrl: baseUrl,
          apiKey: effectiveApiKey,
        );
        ulinkConfig = await apiClient.getProjectConfig(effectiveProjectId);
        fetchConfigSpinner.success('ULink configuration fetched');
        results.add(
          VerificationResult(
            checkName: 'ULink API Connection',
            status: VerificationStatus.success,
            message: 'Successfully fetched project configuration',
          ),
        );
      } catch (e) {
        fetchConfigSpinner.fail('Failed to fetch configuration');
        results.add(
          VerificationResult(
            checkName: 'ULink API Connection',
            status: VerificationStatus.error,
            message: 'Failed to fetch project configuration: $e',
            fixSuggestion:
                'Check your credentials. Run "ulink login" to authenticate.',
          ),
        );
      }
    } else if (effectiveProjectId == null) {
      results.add(
        VerificationResult(
          checkName: 'ULink API Connection',
          status: VerificationStatus.skipped,
          message: 'Project ID and credentials not provided',
          fixSuggestion:
              'Run "ulink login" to authenticate, or provide --project-id and --api-key',
        ),
      );
    }

    // 5. Cross-reference configurations
    if (ulinkConfig != null && localConfig != null) {
      final crossRefSpinner = ProgressSpinner('Cross-referencing configurations...', verbose: verbose);
      crossRefSpinner.start();

      if (projectType == ProjectType.flutter ||
          projectType == ProjectType.ios) {
        results.addAll(ConfigValidator.validateIos(localConfig, ulinkConfig));
      }
      if (projectType == ProjectType.flutter ||
          projectType == ProjectType.android) {
        results.addAll(
          ConfigValidator.validateAndroid(localConfig, ulinkConfig),
        );
      }
      crossRefSpinner.success('Cross-referenced configurations');
    }

    // 6. Test well-known files
    if (ulinkConfig != null && ulinkConfig.domains.isNotEmpty) {
      final wellKnownSpinner = ProgressSpinner('Testing well-known files...', verbose: verbose);
      wellKnownSpinner.start();

      final verifiedDomains =
          ulinkConfig.domains.where((d) => d.status == 'verified').toList();
      final verifiedDomain =
          verifiedDomains.isNotEmpty ? verifiedDomains.first : null;

      if (verifiedDomain != null) {
        // Test AASA file for iOS
        if (projectType == ProjectType.flutter ||
            projectType == ProjectType.ios) {
          if (ulinkConfig.iosTeamId != null &&
              ulinkConfig.iosBundleIdentifier != null) {
            final aasaResult = await WellKnownTester.testAasaFile(
              verifiedDomain.host,
              ulinkConfig.iosTeamId,
              ulinkConfig.iosBundleIdentifier,
            );
            results.add(aasaResult);
          }
        }

        // Test Asset Links file for Android
        if (projectType == ProjectType.flutter ||
            projectType == ProjectType.android) {
          if (ulinkConfig.androidPackageName != null) {
            final assetLinksResult = await WellKnownTester.testAssetLinksFile(
              verifiedDomain.host,
              ulinkConfig.androidPackageName,
              ulinkConfig.androidSha256Fingerprints,
            );
            results.add(assetLinksResult);
          }
        }
        wellKnownSpinner.success('Well-known files tested');
      } else {
        wellKnownSpinner.warn('No verified domains to test');
      }
    }

    // 7. Runtime tests (optional, can be skipped if devices not available)
    if (projectType == ProjectType.flutter || projectType == ProjectType.ios) {
      if (ulinkConfig != null && ulinkConfig.domains.isNotEmpty) {
        final iosRuntimeSpinner = ProgressSpinner('Running iOS runtime tests...', verbose: verbose);
        iosRuntimeSpinner.start();

        final verifiedDomains =
            ulinkConfig.domains.where((d) => d.status == 'verified').toList();
        final domain = verifiedDomains.isNotEmpty
            ? verifiedDomains.first
            : ulinkConfig.domains.first;

        // Check domain association status instead of just opening URL
        final runtimeResult =
            await IosRuntimeTester.checkDomainAssociationStatus(
          domain.host,
          localConfig?.bundleIdentifier,
        );
        results.add(runtimeResult);

        if (runtimeResult.status == VerificationStatus.success) {
          iosRuntimeSpinner.success('iOS runtime tests passed');
        } else if (runtimeResult.status == VerificationStatus.warning) {
          iosRuntimeSpinner.warn('iOS runtime tests completed with warnings');
        } else if (runtimeResult.status == VerificationStatus.skipped) {
          iosRuntimeSpinner.success('iOS runtime tests skipped');
        } else {
          iosRuntimeSpinner.fail('iOS runtime tests failed');
        }
      }
    }

    if (projectType == ProjectType.flutter ||
        projectType == ProjectType.android) {
      if (ulinkConfig != null && localConfig?.packageName != null) {
        final androidRuntimeSpinner = ProgressSpinner('Running Android runtime tests...', verbose: verbose);
        androidRuntimeSpinner.start();

        final statusResult = await AndroidRuntimeTester.getAppLinksStatus(
          localConfig!.packageName!,
        );
        results.add(statusResult);

        if (statusResult.status == VerificationStatus.success) {
          androidRuntimeSpinner.success('Android runtime tests passed');
        } else if (statusResult.status == VerificationStatus.warning) {
          androidRuntimeSpinner.warn('Android runtime tests completed with warnings');
        } else if (statusResult.status == VerificationStatus.skipped) {
          androidRuntimeSpinner.success('Android runtime tests skipped');
        } else {
          androidRuntimeSpinner.fail('Android runtime tests failed');
        }
      }
    }

    // Generate and display report
    final report = VerificationReport(
      projectType: projectType,
      results: results,
    );

    print(ReportGenerator.generateReport(report, verbose: verbose));

    // Auto-upload results to ULink dashboard if authenticated
    if (effectiveProjectId != null && hasCredentials) {
      final uploadSpinner = ProgressSpinner('Syncing results to dashboard...', verbose: verbose);
      uploadSpinner.start();

      try {
        final apiClient = ULinkApiClient(
          baseUrl: baseUrl,
          apiKey: effectiveApiKey,
        );

        // Generate JSON report with passed status
        final jsonReport = ReportGenerator.generateJsonReport(report);
        jsonReport['passed'] = !report.hasErrors;

        await apiClient.postVerificationResults(effectiveProjectId, jsonReport);
        uploadSpinner.success('Results synced to dashboard');
      } catch (e) {
        // Don't fail the verification if upload fails
        uploadSpinner.warn('Could not sync results to dashboard');
        if (verbose) {
          stderr.writeln(ConsoleStyle.warning('The verification completed locally, but results were not synced to the dashboard.'));
          stderr.writeln(ConsoleStyle.dim('Error: $e'));
        }
      }
    }

    // Exit with appropriate code
    if (report.hasErrors) {
      exit(1);
    } else {
      exit(0);
    }
  }
}
