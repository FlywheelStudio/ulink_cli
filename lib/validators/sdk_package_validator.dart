import 'dart:io';
import 'package:yaml/yaml.dart';
import '../models/verification_result.dart';
import '../models/platform_config.dart';
import '../parsers/project_detector.dart';

/// Validates that ULink SDK package is installed
class SdkPackageValidator {
  /// Validate SDK installation for a project
  static List<VerificationResult> validate(
    String projectPath,
    ProjectType projectType,
  ) {
    final results = <VerificationResult>[];

    if (projectType == ProjectType.flutter) {
      results.addAll(_validateFlutter(projectPath));
    } else if (projectType == ProjectType.android) {
      results.addAll(_validateAndroid(projectPath));
    } else if (projectType == ProjectType.ios) {
      results.addAll(_validateIos(projectPath));
    }

    return results;
  }

  /// Validate Flutter SDK installation
  static List<VerificationResult> _validateFlutter(String projectPath) {
    final results = <VerificationResult>[];
    final pubspecFile = ProjectDetector.findPubspecYaml(projectPath);

    if (pubspecFile == null) {
      results.add(
        VerificationResult(
          checkName: 'SDK Package - Flutter',
          status: VerificationStatus.error,
          message: 'pubspec.yaml not found',
          fixSuggestion:
              'Ensure you are running the command from a Flutter project root',
        ),
      );
      return results;
    }

    try {
      final content = pubspecFile.readAsStringSync();
      final yaml = loadYaml(content) as Map;

      // Check dependencies section
      final dependencies = yaml['dependencies'] as Map?;
      if (dependencies == null) {
        results.add(
          VerificationResult(
            checkName: 'SDK Package - Flutter',
            status: VerificationStatus.error,
            message: 'No dependencies section found in pubspec.yaml',
            fixSuggestion: 'Add a dependencies section to pubspec.yaml',
          ),
        );
        return results;
      }

      // Check for flutter_ulink_sdk
      final hasSdk = dependencies.containsKey('flutter_ulink_sdk');
      if (!hasSdk) {
        results.add(
          VerificationResult(
            checkName: 'SDK Package - Flutter',
            status: VerificationStatus.error,
            message: 'flutter_ulink_sdk not found in dependencies',
            fixSuggestion:
                'Add flutter_ulink_sdk to your pubspec.yaml dependencies:\n'
                '  dependencies:\n'
                '    flutter_ulink_sdk: ^0.1.0',
          ),
        );
        return results;
      }

      // Check pubspec.lock to verify package was resolved
      final lockFile = File(projectPath + '/pubspec.lock');
      if (lockFile.existsSync()) {
        final lockContent = lockFile.readAsStringSync();
        if (!lockContent.contains('flutter_ulink_sdk')) {
          results.add(
            VerificationResult(
              checkName: 'SDK Package - Flutter',
              status: VerificationStatus.warning,
              message:
                  'flutter_ulink_sdk found in pubspec.yaml but not in pubspec.lock',
              fixSuggestion: 'Run: flutter pub get',
            ),
          );
        } else {
          results.add(
            VerificationResult(
              checkName: 'SDK Package - Flutter',
              status: VerificationStatus.success,
              message: 'flutter_ulink_sdk is installed and resolved',
            ),
          );
        }
      } else {
        results.add(
          VerificationResult(
            checkName: 'SDK Package - Flutter',
            status: VerificationStatus.warning,
            message: 'pubspec.lock not found',
            fixSuggestion: 'Run: flutter pub get',
          ),
        );
      }
    } catch (e) {
      results.add(
        VerificationResult(
          checkName: 'SDK Package - Flutter',
          status: VerificationStatus.error,
          message: 'Error parsing pubspec.yaml: $e',
        ),
      );
    }

    return results;
  }

  /// Validate Android SDK installation
  static List<VerificationResult> _validateAndroid(String projectPath) {
    final results = <VerificationResult>[];
    final gradleFiles = ProjectDetector.findGradleFiles(
      projectPath,
      ProjectType.android,
    );

    if (gradleFiles.isEmpty) {
      results.add(
        VerificationResult(
          checkName: 'SDK Package - Android',
          status: VerificationStatus.error,
          message: 'No build.gradle files found',
          fixSuggestion:
              'Ensure you are running the command from an Android project root',
        ),
      );
      return results;
    }

    bool foundSdk = false;

    // Prioritize app-level build.gradle files (where dependencies usually are)
    final sortedFiles = List<File>.from(gradleFiles);
    sortedFiles.sort((a, b) {
      final aIsApp = a.path.contains('/app/') || a.path.contains('\\app\\');
      final bIsApp = b.path.contains('/app/') || b.path.contains('\\app\\');
      if (aIsApp && !bIsApp) return -1;
      if (!aIsApp && bIsApp) return 1;
      return 0;
    });

    for (final gradleFile in sortedFiles) {
      try {
        final content = gradleFile.readAsStringSync();

        // Check for ULink SDK dependency - check if line contains both parts for GitHub
        final hasUlinkSdk = content.contains('ly.ulink:ulink-sdk');
        final hasGitHubSdk = content.contains('com.github') &&
            content.contains('android-ulink-sdk') &&
            RegExp(r'com\.github[^\s]*android-ulink-sdk').hasMatch(content);

        if (hasUlinkSdk || hasGitHubSdk) {
          foundSdk = true;

          // Check if it's commented out
          final lines = content.split('\n');
          bool isCommented = false;
          for (final line in lines) {
            if (line.contains('ly.ulink:ulink-sdk') ||
                (line.contains('com.github') &&
                    line.contains('android-ulink-sdk'))) {
              if (line.trim().startsWith('//')) {
                isCommented = true;
                break;
              }
            }
          }

          if (isCommented) {
            results.add(
              VerificationResult(
                checkName: 'SDK Package - Android',
                status: VerificationStatus.error,
                message:
                    'ULink SDK dependency is commented out in ${gradleFile.path}',
                fixSuggestion: 'Uncomment the ULink SDK dependency',
              ),
            );
            return results;
          }

          results.add(
            VerificationResult(
              checkName: 'SDK Package - Android',
              status: VerificationStatus.success,
              message: 'ULink SDK found in ${gradleFile.path}',
            ),
          );
          break;
        }
      } catch (e) {
        // Continue to next file
      }
    }

    if (!foundSdk) {
      results.add(
        VerificationResult(
          checkName: 'SDK Package - Android',
          status: VerificationStatus.error,
          message: 'ULink SDK not found in build.gradle files',
          fixSuggestion: 'Add ULink SDK to your dependencies:\n'
              '  dependencies {\n'
              '    implementation("ly.ulink:ulink-sdk:1.0.5")\n'
              '  }',
        ),
      );
    }

    return results;
  }

  /// Validate iOS SDK installation
  static List<VerificationResult> _validateIos(String projectPath) {
    final results = <VerificationResult>[];
    bool foundInPods = false;
    bool foundInSpm = false;

    // Check Podfile
    final podfile = ProjectDetector.findPodfile(projectPath, ProjectType.ios);
    if (podfile != null) {
      try {
        final content = podfile.readAsStringSync();
        if (content.contains("pod 'ULinkSDK'") ||
            content.contains('pod "ULinkSDK"')) {
          foundInPods = true;
          // Check Podfile.lock
          final lockFile = File(projectPath + '/Podfile.lock');
          if (lockFile.existsSync()) {
            final lockContent = lockFile.readAsStringSync();
            if (lockContent.contains('ULinkSDK')) {
              results.add(
                VerificationResult(
                  checkName: 'SDK Package - iOS (CocoaPods)',
                  status: VerificationStatus.success,
                  message: 'ULinkSDK found in Podfile and Podfile.lock',
                ),
              );
            } else {
              results.add(
                VerificationResult(
                  checkName: 'SDK Package - iOS (CocoaPods)',
                  status: VerificationStatus.warning,
                  message: 'ULinkSDK found in Podfile but not in Podfile.lock',
                  fixSuggestion: 'Run: pod install',
                ),
              );
            }
          } else {
            results.add(
              VerificationResult(
                checkName: 'SDK Package - iOS (CocoaPods)',
                status: VerificationStatus.warning,
                message: 'Podfile.lock not found',
                fixSuggestion: 'Run: pod install',
              ),
            );
          }
        }
      } catch (e) {
        // Continue to check Package.swift
      }
    }

    // Check Package.swift for SPM
    final packageSwift = ProjectDetector.findPackageSwift(
      projectPath,
      ProjectType.ios,
    );
    if (packageSwift != null) {
      try {
        final content = packageSwift.readAsStringSync();
        if (content.contains('ULinkSDK') ||
            content.contains('ios_ulink_sdk') ||
            content.contains('github.com') && content.contains('ulink')) {
          foundInSpm = true;
          results.add(
            VerificationResult(
              checkName: 'SDK Package - iOS (SPM)',
              status: VerificationStatus.success,
              message: 'ULinkSDK found in Package.swift',
            ),
          );
        }
      } catch (e) {
        // Continue
      }
    }

    // No SDK found in either
    if (!foundInPods && !foundInSpm) {
      results.add(
        VerificationResult(
          checkName: 'SDK Package - iOS',
          status: VerificationStatus.error,
          message: 'ULinkSDK not found in Podfile or Package.swift',
          fixSuggestion: 'Add ULinkSDK to your Podfile:\n'
              "  pod 'ULinkSDK', '~> 1.0.0'\n"
              'Or add it via Swift Package Manager in Xcode',
        ),
      );
    }

    return results;
  }
}
