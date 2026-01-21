import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;

/// Utility for loading test fixtures
class FixtureLoader {
  static final String _fixturesPath = path.join(
    path.dirname(Platform.script.toFilePath()),
    'fixtures',
  );

  /// Get the fixtures directory path
  static String get fixturesPath {
    // When running tests, use the test/fixtures path relative to the package root
    final scriptPath = Platform.script.toFilePath();

    // Handle both direct script execution and package test execution
    if (scriptPath.contains('test')) {
      return path.join(path.dirname(scriptPath), 'fixtures');
    }

    // Default to looking for fixtures in the test directory
    return path.join(Directory.current.path, 'test', 'fixtures');
  }

  /// Load a fixture file as a string
  static Future<String> loadString(String relativePath) async {
    final file = File(path.join(fixturesPath, relativePath));
    if (!await file.exists()) {
      throw FileSystemException('Fixture not found: $relativePath', file.path);
    }
    return file.readAsString();
  }

  /// Load a fixture file synchronously
  static String loadStringSync(String relativePath) {
    final file = File(path.join(fixturesPath, relativePath));
    if (!file.existsSync()) {
      throw FileSystemException('Fixture not found: $relativePath', file.path);
    }
    return file.readAsStringSync();
  }

  /// Load a JSON fixture and parse it
  static Future<Map<String, dynamic>> loadJson(String relativePath) async {
    final content = await loadString(relativePath);
    return jsonDecode(content) as Map<String, dynamic>;
  }

  /// Load a JSON fixture synchronously
  static Map<String, dynamic> loadJsonSync(String relativePath) {
    final content = loadStringSync(relativePath);
    return jsonDecode(content) as Map<String, dynamic>;
  }

  /// Get a fixture file path
  static String getFixturePath(String relativePath) {
    return path.join(fixturesPath, relativePath);
  }

  /// Check if a fixture exists
  static bool fixtureExists(String relativePath) {
    return File(path.join(fixturesPath, relativePath)).existsSync();
  }
}

/// Sample API responses for testing
class ApiResponseFixtures {
  /// Sample project configuration response
  static Map<String, dynamic> get projectConfig => {
        'projectId': 'test-project-123',
        'ios_bundle_identifier': 'com.example.testapp',
        'ios_team_id': 'ABC123DEFG',
        'ios_deeplink_schema': 'testapp://',
        'android_package_name': 'com.example.testapp',
        'android_sha256_fingerprints': [
          'AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99'
        ],
        'android_deeplink_schema': 'testapp://',
        'domains': [
          {
            'id': 'domain-1',
            'host': 'example.com',
            'status': 'verified',
            'isPrimary': true,
          },
          {
            'id': 'domain-2',
            'host': 'test.example.com',
            'status': 'pending',
            'isPrimary': false,
          },
        ],
      };

  /// Sample project list response
  static List<Map<String, dynamic>> get projectList => [
        {
          'projectId': 'project-1',
          'projectName': 'Test Project 1',
          'createdAt': '2024-01-01T00:00:00Z',
        },
        {
          'projectId': 'project-2',
          'projectName': 'Test Project 2',
          'createdAt': '2024-01-02T00:00:00Z',
        },
      ];

  /// Sample error responses
  static Map<String, dynamic> get unauthorizedError => {
        'error': 'Unauthorized',
        'message': 'Invalid or expired token',
        'statusCode': 401,
      };

  static Map<String, dynamic> get notFoundError => {
        'error': 'Not Found',
        'message': 'Project not found',
        'statusCode': 404,
      };

  static Map<String, dynamic> get forbiddenError => {
        'error': 'Forbidden',
        'message': 'You do not have access to this project',
        'statusCode': 403,
      };
}
