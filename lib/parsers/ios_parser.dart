import 'dart:io';
import 'package:plist_parser/plist_parser.dart';
import 'package:path/path.dart' as path;
import '../models/platform_config.dart';

/// Parser for iOS Info.plist files
class IosParser {
  /// Parse Info.plist file
  static PlatformConfig? parseInfoPlist(File infoPlistFile) {
    try {
      final content = infoPlistFile.readAsStringSync();
      final plist = PlistParser().parse(content);

      var bundleIdentifier = plist['CFBundleIdentifier'] as String?;
      final urlTypes = plist['CFBundleURLTypes'] as List?;
      final urlSchemes = <String>[];

      // Resolve Xcode build variables like $(PRODUCT_BUNDLE_IDENTIFIER)
      if (bundleIdentifier != null && _isXcodeVariable(bundleIdentifier)) {
        final resolvedId = _resolveXcodeVariable(
          bundleIdentifier,
          infoPlistFile.parent.path,
        );
        if (resolvedId != null) {
          bundleIdentifier = resolvedId;
        }
      }

      if (urlTypes != null) {
        for (final urlType in urlTypes) {
          if (urlType is Map) {
            final schemes = urlType['CFBundleURLSchemes'] as List?;
            if (schemes != null) {
              for (final scheme in schemes) {
                if (scheme is String) {
                  urlSchemes.add(scheme);
                }
              }
            }
          }
        }
      }

      // Extract team ID from Xcode project file
      String? teamId;
      if (bundleIdentifier != null) {
        // Try to find project.pbxproj and extract DEVELOPMENT_TEAM
        teamId = _extractTeamIdFromProject(infoPlistFile.parent.path);
      }

      return PlatformConfig(
        projectType: ProjectType.ios,
        bundleIdentifier: bundleIdentifier,
        urlSchemes: urlSchemes,
        iosUrlSchemes: urlSchemes,
        teamId: teamId,
      );
    } catch (e) {
      return null;
    }
  }

  /// Check if a value is an Xcode build variable
  static bool _isXcodeVariable(String value) {
    return value.contains(r'$(') || value.contains(r'${');
  }

  /// Resolve Xcode build variable to its actual value
  static String? _resolveXcodeVariable(String variable, String infoPlistDir) {
    // Extract variable name from $(VAR_NAME) or ${VAR_NAME}
    final varMatch = RegExp(r'\$[\(\{]([A-Z_]+)[\)\}]').firstMatch(variable);
    if (varMatch == null) return null;

    final varName = varMatch.group(1);
    if (varName == null) return null;

    // Search for the variable in Xcode project files
    // Try to find project.pbxproj in parent directories
    var searchDir = Directory(infoPlistDir);

    // Walk up to find the iOS project root (look for .xcodeproj)
    for (var i = 0; i < 5; i++) {
      final xcodeprojs = searchDir
          .listSync()
          .whereType<Directory>()
          .where((d) => d.path.endsWith('.xcodeproj'))
          .toList();

      if (xcodeprojs.isNotEmpty) {
        // Found .xcodeproj, look for project.pbxproj
        for (final xcodeproj in xcodeprojs) {
          final pbxproj = File(path.join(xcodeproj.path, 'project.pbxproj'));
          if (pbxproj.existsSync()) {
            final resolved = _extractVariableFromPbxproj(pbxproj, varName);
            if (resolved != null) {
              return resolved;
            }
          }
        }
      }

      // Move up to parent directory
      final parent = searchDir.parent;
      if (parent.path == searchDir.path) break;
      searchDir = parent;
    }

    return null;
  }

  /// Extract variable value from project.pbxproj file
  static String? _extractVariableFromPbxproj(File pbxproj, String varName) {
    try {
      final content = pbxproj.readAsStringSync();

      // Look for the variable assignment (e.g., PRODUCT_BUNDLE_IDENTIFIER = com.example.app;)
      // We want the main target's value, not test targets
      final pattern = RegExp(
        r'^\s*' + RegExp.escape(varName) + r'\s*=\s*([^;]+);',
        multiLine: true,
      );

      final matches = pattern.allMatches(content).toList();

      if (matches.isEmpty) return null;

      // Filter out test bundle identifiers (those containing "Tests" or "Test")
      for (final match in matches) {
        final value = match.group(1)?.trim();
        if (value != null &&
            !value.contains('Test') &&
            !value.contains(r'${') &&
            !value.contains(r'$(')) {
          // Remove quotes if present
          final cleanValue = value.replaceAll('"', '').replaceAll("'", '');
          return cleanValue;
        }
      }

      // If all values contain Test, return the first non-variable value
      for (final match in matches) {
        final value = match.group(1)?.trim();
        if (value != null && !value.contains(r'${') && !value.contains(r'$(')) {
          final cleanValue = value.replaceAll('"', '').replaceAll("'", '');
          return cleanValue;
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Parse entitlements file
  static List<String> parseEntitlements(File entitlementsFile) {
    try {
      final content = entitlementsFile.readAsStringSync();
      final plist = PlistParser().parse(content);

      final associatedDomains =
          plist['com.apple.developer.associated-domains'] as List?;
      if (associatedDomains == null) {
        return [];
      }

      final domains = <String>[];
      for (final domain in associatedDomains) {
        if (domain is String) {
          // Remove 'applinks:' prefix if present
          final cleanDomain =
              domain.startsWith('applinks:') ? domain.substring(9) : domain;
          domains.add(cleanDomain);
        }
      }

      return domains;
    } catch (e) {
      return [];
    }
  }

  /// Extract team ID from Xcode project file (project.pbxproj)
  /// Looks for DEVELOPMENT_TEAM setting in the project file
  static String? _extractTeamIdFromProject(String infoPlistDir) {
    // Walk up to find the iOS project root (look for .xcodeproj)
    var searchDir = Directory(infoPlistDir);

    for (var i = 0; i < 5; i++) {
      final xcodeprojs = searchDir
          .listSync()
          .whereType<Directory>()
          .where((d) => d.path.endsWith('.xcodeproj'))
          .toList();

      if (xcodeprojs.isNotEmpty) {
        // Found .xcodeproj, look for project.pbxproj
        for (final xcodeproj in xcodeprojs) {
          final pbxproj = File(path.join(xcodeproj.path, 'project.pbxproj'));
          if (pbxproj.existsSync()) {
            final teamId = _extractTeamIdFromPbxproj(pbxproj);
            if (teamId != null) {
              return teamId;
            }
          }
        }
      }

      // Move up to parent directory
      final parent = searchDir.parent;
      if (parent.path == searchDir.path) break;
      searchDir = parent;
    }

    return null;
  }

  /// Extract DEVELOPMENT_TEAM from project.pbxproj file
  static String? _extractTeamIdFromPbxproj(File pbxproj) {
    try {
      final content = pbxproj.readAsStringSync();

      // Look for DEVELOPMENT_TEAM = "TEAM_ID";
      // This can appear in build configurations or project-level settings
      final patterns = [
        // Pattern 1: DEVELOPMENT_TEAM = "ABC123DEFG";
        RegExp(r'DEVELOPMENT_TEAM\s*=\s*"?([A-Z0-9]{10})"?\s*;',
            multiLine: true),
        // Pattern 2: DEVELOPMENT_TEAM = TEAM_ID;
        RegExp(r'DEVELOPMENT_TEAM\s*=\s*([A-Z0-9]{10})\s*;', multiLine: true),
      ];

      for (final pattern in patterns) {
        final matches = pattern.allMatches(content);
        for (final match in matches) {
          final teamId = match.group(1);
          if (teamId != null && teamId.length == 10) {
            // Apple Team IDs are 10 characters (alphanumeric)
            return teamId;
          }
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Extract team ID from bundle identifier (if it contains team ID)
  /// Note: This is a best-effort approach. Team ID is usually in the entitlements
  /// or Xcode project settings, not directly in Info.plist
  static String? extractTeamId(String? bundleIdentifier) {
    // Bundle identifier format: TEAM_ID.BUNDLE_ID
    // This is a heuristic - actual team ID should come from project config
    if (bundleIdentifier == null) return null;
    final parts = bundleIdentifier.split('.');
    if (parts.length >= 2) {
      // First part might be team ID if it's 10 characters (Apple team ID format)
      final firstPart = parts[0];
      if (firstPart.length == 10 &&
          firstPart.contains(RegExp(r'^[A-Z0-9]+$'))) {
        return firstPart;
      }
    }
    return null;
  }
}
