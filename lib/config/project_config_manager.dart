import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;

/// Manages per-directory project configuration
/// Stores project ID in .ulink/project.json in the current directory
class ProjectConfigManager {
  static const String configDirName = '.ulink';
  static const String configFileName = 'project.json';

  /// Get the project config file path for a given directory
  static String _getConfigPath(String projectPath) {
    final absolutePath = path.isAbsolute(projectPath)
        ? projectPath
        : path.join(Directory.current.path, projectPath);
    return path.join(absolutePath, configDirName, configFileName);
  }

  /// Get the project config directory path
  static String _getConfigDir(String projectPath) {
    final absolutePath = path.isAbsolute(projectPath)
        ? projectPath
        : path.join(Directory.current.path, projectPath);
    return path.join(absolutePath, configDirName);
  }

  /// Load project ID from directory config
  static String? loadProjectId(String projectPath) {
    try {
      final configFile = File(_getConfigPath(projectPath));
      if (!configFile.existsSync()) {
        return null;
      }

      final content = configFile.readAsStringSync();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return json['projectId'] as String?;
    } catch (e) {
      // If file doesn't exist or is invalid, return null
      return null;
    }
  }

  /// Save project ID to directory config
  static Future<void> saveProjectId(String projectPath, String projectId,
      {String? projectName}) async {
    try {
      final configDir = Directory(_getConfigDir(projectPath));
      if (!configDir.existsSync()) {
        configDir.createSync(recursive: true);
      }

      final configFile = File(_getConfigPath(projectPath));
      final config = <String, dynamic>{
        'projectId': projectId,
        if (projectName != null) 'projectName': projectName,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      await configFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(config),
      );

      // Set restrictive permissions (600) for security
      if (Platform.isLinux || Platform.isMacOS) {
        final process = await Process.run(
          'chmod',
          ['600', configFile.path],
        );
        if (process.exitCode != 0) {
          // Silently fail - permissions are best effort
        }
      }
    } catch (e) {
      throw Exception('Failed to save project configuration: $e');
    }
  }
}
