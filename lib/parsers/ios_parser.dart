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
          infoPlistFile,
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

  /// Resolve an Xcode build variable (e.g. `$(PRODUCT_BUNDLE_IDENTIFIER)`) that
  /// appears in [infoPlistFile] to its literal value.
  ///
  /// For `PRODUCT_BUNDLE_IDENTIFIER` the value is resolved *for the target that
  /// owns this Info.plist*, not by grabbing the first match in the pbxproj.
  /// A multi-target project (app + notification/widget extensions + tests) holds
  /// several `PRODUCT_BUNDLE_IDENTIFIER` values; the extension ones do not
  /// contain "Test", so a first-match heuristic could resolve the app's bundle
  /// id to an extension's. Resolution order:
  ///   1. the build configuration whose `INFOPLIST_FILE` points at this plist,
  ///   2. the application target (`product-type.application`),
  ///   3. the legacy first-non-test heuristic (also covers other variables).
  static String? _resolveXcodeVariable(String variable, File infoPlistFile) {
    // Extract variable name from $(VAR_NAME) or ${VAR_NAME}
    final varMatch = RegExp(r'\$[\(\{]([A-Z_]+)[\)\}]').firstMatch(variable);
    if (varMatch == null) return null;

    final varName = varMatch.group(1);
    if (varName == null) return null;

    // Search for the variable in Xcode project files
    // Try to find project.pbxproj in parent directories
    var searchDir = infoPlistFile.parent;

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
          if (!pbxproj.existsSync()) continue;

          if (varName == 'PRODUCT_BUNDLE_IDENTIFIER') {
            // The .xcodeproj's parent directory is SRCROOT; INFOPLIST_FILE
            // values in the pbxproj are relative to it.
            final srcRoot = xcodeproj.parent.path;
            final scoped = _bundleIdForInfoPlist(
                  pbxproj, srcRoot, infoPlistFile) ??
                _bundleIdForApplicationTarget(pbxproj);
            if (scoped != null) return scoped;
          }

          final resolved = _extractVariableFromPbxproj(pbxproj, varName);
          if (resolved != null) return resolved;
        }
      }

      // Move up to parent directory
      final parent = searchDir.parent;
      if (parent.path == searchDir.path) break;
      searchDir = parent;
    }

    return null;
  }

  /// Resolve `PRODUCT_BUNDLE_IDENTIFIER` from the build configuration whose
  /// `INFOPLIST_FILE` points at [infoPlistFile]. This ties the value to the
  /// exact target that owns the plist. Returns null if no build configuration
  /// references this plist (e.g. the target uses `GENERATE_INFOPLIST_FILE`).
  static String? _bundleIdForInfoPlist(
    File pbxproj,
    String srcRoot,
    File infoPlistFile,
  ) {
    try {
      final content = pbxproj.readAsStringSync();
      final wantRel = path
          .relative(infoPlistFile.absolute.path, from: File(srcRoot).absolute.path)
          .replaceAll(r'\', '/');

      for (final block in _buildSettingsBlocks(content)) {
        final infoPlist = _setting(block, 'INFOPLIST_FILE');
        if (infoPlist == null) continue;
        if (!_infoPlistMatches(_normalizePbxPath(infoPlist), wantRel)) continue;

        final bundleId = _cleanValue(_setting(block, 'PRODUCT_BUNDLE_IDENTIFIER'));
        if (bundleId != null && !_isXcodeVariable(bundleId)) return bundleId;
      }
    } catch (_) {
      // fall through to the next strategy
    }
    return null;
  }

  /// Resolve `PRODUCT_BUNDLE_IDENTIFIER` for the application target
  /// (`com.apple.product-type.application`) by walking
  /// PBXNativeTarget -> XCConfigurationList -> XCBuildConfiguration.
  static String? _bundleIdForApplicationTarget(File pbxproj) {
    try {
      final content = pbxproj.readAsStringSync();

      String? listUuid;
      for (final obj in _objectsByIsa(content, 'PBXNativeTarget')) {
        // Match the exact quoted product type. A substring match would also
        // catch `...application.watchapp2` and `...application.on-demand-
        // install-capable` (App Clip), letting a watch app or clip masquerade
        // as the main app and yield the wrong bundle id. Xcode always writes
        // productType double-quoted, so the trailing quote makes this exact.
        if (obj.contains('"com.apple.product-type.application"')) {
          listUuid = _firstUuid(obj, 'buildConfigurationList');
          break;
        }
      }
      if (listUuid == null) return null;

      final listObj = _objectByUuid(content, listUuid);
      if (listObj == null) return null;

      for (final cfgUuid in _uuidList(listObj, 'buildConfigurations')) {
        final cfgObj = _objectByUuid(content, cfgUuid);
        if (cfgObj == null) continue;
        final bundleId = _cleanValue(_setting(cfgObj, 'PRODUCT_BUNDLE_IDENTIFIER'));
        if (bundleId != null && !_isXcodeVariable(bundleId)) return bundleId;
      }
    } catch (_) {
      // fall through to the legacy heuristic
    }
    return null;
  }

  // --- pbxproj micro-parser helpers -----------------------------------------

  /// Yield the text of every `buildSettings = { ... }` block, brace-balanced.
  static Iterable<String> _buildSettingsBlocks(String content) sync* {
    const marker = 'buildSettings = {';
    var idx = content.indexOf(marker);
    while (idx != -1) {
      final start = idx + marker.length;
      final end = _matchBrace(content, start);
      if (end == -1) return;
      yield content.substring(start, end);
      idx = content.indexOf(marker, end);
    }
  }

  /// Yield each top-level object block (`{ ... }`) whose `isa` equals [isa].
  static Iterable<String> _objectsByIsa(String content, String isa) sync* {
    final needle = 'isa = $isa;';
    var idx = content.indexOf(needle);
    while (idx != -1) {
      final open = content.lastIndexOf('{', idx);
      if (open != -1) {
        final end = _matchBrace(content, open + 1);
        if (end != -1) yield content.substring(open + 1, end);
      }
      idx = content.indexOf(needle, idx + needle.length);
    }
  }

  /// Return the object block (`{ ... }`) defined as `<uuid> ... = { ... }`.
  static String? _objectByUuid(String content, String uuid) {
    final re = RegExp('$uuid' r'\b\s*(?:/\*[^*]*\*/)?\s*=\s*\{');
    final m = re.firstMatch(content);
    if (m == null) return null;
    final open = content.indexOf('{', m.start);
    final end = _matchBrace(content, open + 1);
    if (end == -1) return null;
    return content.substring(open + 1, end);
  }

  /// Index just past the `}` that closes the block opened before [start]
  /// (i.e. [start] is the index right after the opening `{`). Returns -1 if
  /// unbalanced.
  static int _matchBrace(String content, int start) {
    var depth = 1;
    var j = start;
    while (j < content.length && depth > 0) {
      final ch = content[j];
      if (ch == '{') {
        depth++;
      } else if (ch == '}') {
        depth--;
      }
      j++;
    }
    return depth == 0 ? j - 1 : -1;
  }

  /// Read a `KEY = value;` setting from a block.
  static String? _setting(String block, String key) {
    final m = RegExp('^\\s*${RegExp.escape(key)}' r'\s*=\s*([^;]+);',
            multiLine: true)
        .firstMatch(block);
    return m?.group(1)?.trim();
  }

  /// First UUID referenced by `KEY = <uuid> ...;` in a block.
  static String? _firstUuid(String block, String key) {
    final m = RegExp('${RegExp.escape(key)}' r'\s*=\s*([0-9A-Fa-f]{24})')
        .firstMatch(block);
    return m?.group(1);
  }

  /// UUIDs listed in `KEY = ( uuid, uuid, );`.
  static List<String> _uuidList(String block, String key) {
    final m = RegExp('${RegExp.escape(key)}' r'\s*=\s*\(([^)]*)\)', dotAll: true)
        .firstMatch(block);
    if (m == null) return const [];
    return RegExp(r'[0-9A-Fa-f]{24}')
        .allMatches(m.group(1) ?? '')
        .map((x) => x.group(0)!)
        .toList();
  }

  /// Strip surrounding quotes and whitespace; return null if empty.
  static String? _cleanValue(String? raw) {
    if (raw == null) return null;
    final v = raw.trim().replaceAll('"', '').replaceAll("'", '').trim();
    return v.isEmpty ? null : v;
  }

  /// Normalize an INFOPLIST_FILE value to a SRCROOT-relative POSIX path.
  static String _normalizePbxPath(String raw) {
    var v = _cleanValue(raw) ?? '';
    v = v
        .replaceAll(r'$(SRCROOT)/', '')
        .replaceAll(r'${SRCROOT}/', '')
        .replaceAll('\\', '/');
    if (v.startsWith('./')) v = v.substring(2);
    return v;
  }

  /// Whether a pbxproj INFOPLIST_FILE path refers to the wanted plist. Uses an
  /// exact or suffix match so relative-path differences do not cause misses.
  static bool _infoPlistMatches(String pbxPath, String wantRel) {
    if (pbxPath.isEmpty || wantRel.isEmpty) return false;
    return pbxPath == wantRel ||
        pbxPath.endsWith('/$wantRel') ||
        wantRel.endsWith('/$pbxPath');
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
