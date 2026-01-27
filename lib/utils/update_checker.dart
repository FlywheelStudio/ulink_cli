import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import '../config/version.dart';
import 'console_style.dart';

/// Checks for CLI updates (once per day)
class UpdateChecker {
  static const String _githubRepo = 'FlywheelStudio/ulink_cli';
  static const Duration _checkInterval = Duration(hours: 24);
  static const Duration _timeout = Duration(seconds: 3);

  /// Get the path to the update check cache file
  static String get _cacheFilePath {
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '';
    return path.join(home, '.config', 'ulink', 'update_check.json');
  }

  /// Check for updates and print message if available
  /// This is non-blocking and fails silently
  static Future<void> checkForUpdates() async {
    try {
      // Check if we should check (once per day)
      if (!_shouldCheck()) {
        return;
      }

      // Fetch latest version from GitHub
      final latestVersion = await _fetchLatestVersion();
      if (latestVersion == null) {
        return;
      }

      // Save the check result
      await _saveCheckResult(latestVersion);

      // Compare versions
      if (_isNewerVersion(latestVersion, ULinkVersion.version)) {
        _printUpdateMessage(latestVersion);
      }
    } catch (e) {
      // Fail silently - don't interrupt user's workflow
    }
  }

  /// Check if we have a cached update message to show
  /// This is synchronous and fast - used when we skip the network check
  static void showCachedUpdateMessage() {
    try {
      final cache = _loadCache();
      if (cache == null) return;

      final latestVersion = cache['latestVersion'] as String?;
      if (latestVersion == null) return;

      if (_isNewerVersion(latestVersion, ULinkVersion.version)) {
        _printUpdateMessage(latestVersion);
      }
    } catch (e) {
      // Fail silently
    }
  }

  /// Check if enough time has passed since last check
  static bool _shouldCheck() {
    try {
      final cache = _loadCache();
      if (cache == null) return true;

      final lastCheckStr = cache['lastCheck'] as String?;
      if (lastCheckStr == null) return true;

      final lastCheck = DateTime.parse(lastCheckStr);
      final now = DateTime.now();

      return now.difference(lastCheck) > _checkInterval;
    } catch (e) {
      return true;
    }
  }

  /// Load cached check result
  static Map<String, dynamic>? _loadCache() {
    try {
      final file = File(_cacheFilePath);
      if (!file.existsSync()) return null;

      final content = file.readAsStringSync();
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  /// Save check result to cache
  static Future<void> _saveCheckResult(String latestVersion) async {
    try {
      final file = File(_cacheFilePath);
      await file.parent.create(recursive: true);

      final cache = {
        'lastCheck': DateTime.now().toIso8601String(),
        'latestVersion': latestVersion,
      };

      await file.writeAsString(jsonEncode(cache));
    } catch (e) {
      // Fail silently
    }
  }

  /// Fetch latest version from GitHub releases API
  static Future<String?> _fetchLatestVersion() async {
    try {
      final url = Uri.parse(
        'https://api.github.com/repos/$_githubRepo/releases/latest',
      );

      final response = await http.get(
        url,
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(_timeout);

      if (response.statusCode != 200) {
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tagName = data['tag_name'] as String?;

      if (tagName == null) return null;

      // Remove 'v' prefix if present
      return tagName.startsWith('v') ? tagName.substring(1) : tagName;
    } catch (e) {
      return null;
    }
  }

  /// Compare versions (returns true if latest > current)
  static bool _isNewerVersion(String latest, String current) {
    try {
      final latestParts = latest.split('.').map(int.parse).toList();
      final currentParts = current.split('.').map(int.parse).toList();

      // Pad with zeros if needed
      while (latestParts.length < 3) latestParts.add(0);
      while (currentParts.length < 3) currentParts.add(0);

      // Compare major.minor.patch
      for (int i = 0; i < 3; i++) {
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }

      return false; // Equal versions
    } catch (e) {
      return false;
    }
  }

  /// Print update available message
  static void _printUpdateMessage(String latestVersion) {
    stderr.writeln('');
    stderr.writeln(ConsoleStyle.info(
      '┌─────────────────────────────────────────────────────────┐',
    ));
    stderr.writeln(ConsoleStyle.info(
      '│  A new version of ULink CLI is available: v$latestVersion'.padRight(58) + '│',
    ));
    stderr.writeln(ConsoleStyle.dim(
      '│  You have: v${ULinkVersion.version}'.padRight(58) + '│',
    ));
    stderr.writeln(ConsoleStyle.info(
      '│                                                         │',
    ));
    stderr.writeln(ConsoleStyle.info(
      '│  Run this to update:                                    │',
    ));
    stderr.writeln(ConsoleStyle.success(
      '│  curl -fsSL https://ulink.ly/install.sh | bash          │',
    ));
    stderr.writeln(ConsoleStyle.info(
      '└─────────────────────────────────────────────────────────┘',
    ));
    stderr.writeln('');
  }
}
