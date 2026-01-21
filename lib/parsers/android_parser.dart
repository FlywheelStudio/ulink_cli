import 'dart:io';
import 'package:xml/xml.dart';
import 'package:path/path.dart' as path;
import '../models/platform_config.dart';
import 'project_detector.dart';
import 'gradle_parser.dart';

/// Parser for Android AndroidManifest.xml files
class AndroidParser {
  /// Parse AndroidManifest.xml file
  static PlatformConfig? parseAndroidManifest(File manifestFile) {
    try {
      final content = manifestFile.readAsStringSync();
      final document = XmlDocument.parse(content);
      final manifest = document.rootElement;

      // Debug: Check if document parsed correctly
      if (document.rootElement.name != 'manifest') {
        // Try to continue anyway - might be a namespace issue
      }

      // Extract package name from manifest (older Android projects)
      var packageName = manifest.getAttribute('package');

      // If not found in manifest, try to get from build.gradle (newer projects use namespace)
      if (packageName == null || packageName.isEmpty) {
        // Find project root by looking for build.gradle files
        // Start from manifest directory and walk up until we find build.gradle
        var searchDir = Directory(manifestFile.parent.path);
        var projectRoot = searchDir.path;
        var foundGradle = false;

        // Walk up directories looking for build.gradle
        for (var i = 0; i < 5; i++) {
          final gradleFiles = [
            File(path.join(searchDir.path, 'build.gradle')),
            File(path.join(searchDir.path, 'build.gradle.kts')),
            File(path.join(searchDir.path, 'app', 'build.gradle')),
            File(path.join(searchDir.path, 'app', 'build.gradle.kts')),
          ];

          for (final gradleFile in gradleFiles) {
            if (gradleFile.existsSync()) {
              projectRoot = searchDir.path;
              foundGradle = true;
              final extractedPackage =
                  GradleParser.extractPackageName(gradleFile);
              if (extractedPackage != null) {
                packageName = extractedPackage;
                break;
              }
            }
          }

          if (foundGradle && packageName != null) break;

          // Move up one directory
          final parent = searchDir.parent;
          if (parent.path == searchDir.path) break; // Reached filesystem root
          searchDir = parent;
        }

        // If still not found, try using ProjectDetector with the found project root
        if (packageName == null || packageName.isEmpty) {
          final gradleFiles = ProjectDetector.findGradleFiles(
            projectRoot,
            ProjectType.android,
          );
          for (final gradleFile in gradleFiles) {
            final extractedPackage =
                GradleParser.extractPackageName(gradleFile);
            if (extractedPackage != null) {
              packageName = extractedPackage;
              break;
            }
          }
        }
      }

      // Find all activities with intent filters
      // Use findAllElements to search recursively through the entire document
      final activities = document.findAllElements('activity');
      final urlSchemes = <String>[];
      final appLinkHosts = <String>[];

      for (final activity in activities) {
        final intentFilters = activity.findElements('intent-filter');
        for (final intentFilter in intentFilters) {
          // Check for autoVerify (App Links)
          // Try both with and without namespace prefix
          final autoVerify =
              intentFilter.getAttribute('android:autoVerify') == 'true' ||
                  intentFilter.getAttribute('autoVerify') == 'true';

          // Get actions
          final actions = intentFilter
              .findElements('action')
              .map((e) =>
                  e.getAttribute('android:name') ?? e.getAttribute('name'))
              .where((name) => name != null)
              .cast<String>()
              .toList();

          // Get categories
          final categories = intentFilter
              .findElements('category')
              .map((e) =>
                  e.getAttribute('android:name') ?? e.getAttribute('name'))
              .where((name) => name != null)
              .cast<String>()
              .toList();

          // Check if this is a VIEW intent filter
          // For custom URL schemes, we need VIEW action and BROWSABLE or DEFAULT category
          final isViewIntent = actions.contains('android.intent.action.VIEW');
          final hasBrowsableCategory =
              categories.contains('android.intent.category.BROWSABLE');
          final hasDefaultCategory =
              categories.contains('android.intent.category.DEFAULT');

          // Custom URL schemes typically have VIEW + BROWSABLE
          // App Links have VIEW + BROWSABLE + DEFAULT (and autoVerify)
          // Some apps might only have VIEW + DEFAULT, so we accept that too
          if (isViewIntent && (hasBrowsableCategory || hasDefaultCategory)) {
            // Get data elements
            final dataElements = intentFilter.findElements('data');
            for (final data in dataElements) {
              // Try both with and without namespace prefix
              final scheme = data.getAttribute('android:scheme') ??
                  data.getAttribute('scheme');
              final host = data.getAttribute('android:host') ??
                  data.getAttribute('host');

              if (scheme != null && scheme.isNotEmpty) {
                if (scheme == 'https' &&
                    host != null &&
                    host.isNotEmpty &&
                    autoVerify) {
                  // This is an App Link (universal link)
                  if (!appLinkHosts.contains(host)) {
                    appLinkHosts.add(host);
                  }
                } else if (scheme != 'https' && scheme.isNotEmpty) {
                  // This is a custom URL scheme
                  // Accept schemes with either BROWSABLE or DEFAULT category
                  if (!urlSchemes.contains(scheme)) {
                    urlSchemes.add(scheme);
                  }
                }
              }
            }
          } else if (isViewIntent) {
            // Fallback: If we have VIEW action but no BROWSABLE/DEFAULT categories,
            // still try to extract schemes (some manifests might be missing categories)
            final fallbackDataElements = intentFilter.findElements('data');
            if (fallbackDataElements.isNotEmpty) {
              for (final data in fallbackDataElements) {
                final scheme = data.getAttribute('android:scheme') ??
                    data.getAttribute('scheme');
                if (scheme != null &&
                    scheme.isNotEmpty &&
                    scheme != 'https' &&
                    !urlSchemes.contains(scheme)) {
                  urlSchemes.add(scheme);
                }
              }
            }
          }
        }
      }

      return PlatformConfig(
        projectType: ProjectType.android,
        packageName: packageName,
        urlSchemes: urlSchemes,
        androidUrlSchemes: urlSchemes,
        appLinkHosts: appLinkHosts,
      );
    } catch (e) {
      return null;
    }
  }
}
