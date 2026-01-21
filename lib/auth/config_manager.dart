import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import '../models/auth_config.dart';

/// Manages CLI configuration file
class ConfigManager {
  static String get configDir {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '.';
    return path.join(home, '.ulink');
  }

  static String get configPath {
    return path.join(configDir, 'config.json');
  }

  /// Load configuration from file
  static CliConfig? loadConfig() {
    try {
      final file = File(configPath);
      if (!file.existsSync()) {
        return null;
      }

      final content = file.readAsStringSync();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return CliConfig.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  /// Save configuration to file
  static Future<void> saveConfig(CliConfig config) async {
    try {
      // Ensure directory exists
      final dir = Directory(configDir);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      // Write config file
      final file = File(configPath);
      final json = jsonEncode(config.toJson());
      await file.writeAsString(json);

      // Set restrictive permissions (600) - owner read/write only
      if (Platform.isLinux || Platform.isMacOS) {
        try {
          Process.runSync('chmod', ['600', configPath]);
        } catch (e) {
          // If chmod fails, continue - file permissions may not be critical
        }
      }
    } catch (e) {
      throw Exception('Failed to save config: $e');
    }
  }

  /// Clear configuration (logout)
  static Future<void> clearConfig() async {
    try {
      final file = File(configPath);
      if (file.existsSync()) {
        await file.delete();
      }
    } catch (e) {
      // Ignore errors when clearing
    }
  }

  /// Update auth in config
  static Future<void> updateAuth(AuthConfig auth) async {
    final config = loadConfig() ?? CliConfig();
    final updatedConfig = CliConfig(
      auth: auth,
      projects: config.projects,
      supabaseUrl: config.supabaseUrl,
      supabaseAnonKey: config.supabaseAnonKey,
    );
    await saveConfig(updatedConfig);
  }

  /// Update Supabase configuration
  static Future<void> updateSupabaseConfig({
    String? url,
    String? anonKey,
  }) async {
    final config = loadConfig() ?? CliConfig();
    final updatedConfig = CliConfig(
      auth: config.auth,
      projects: config.projects,
      supabaseUrl: url ?? config.supabaseUrl,
      supabaseAnonKey: anonKey ?? config.supabaseAnonKey,
    );
    await saveConfig(updatedConfig);
  }

  /// Check if user is logged in
  static bool isLoggedIn() {
    final config = loadConfig();
    if (config?.auth == null) return false;

    final auth = config!.auth!;
    if (auth.type == AuthType.apiKey && auth.apiKey != null) {
      return true;
    }

    if (auth.type == AuthType.jwt && auth.token != null) {
      // Check if token is expired
      if (auth.isExpired) {
        return false;
      }
      return true;
    }

    return false;
  }
}
