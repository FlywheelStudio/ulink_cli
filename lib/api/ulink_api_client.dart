import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/project_config.dart';
import '../models/project_list_item.dart';
import '../auth/config_manager.dart';
import '../auth/auth_service.dart';
import '../models/auth_config.dart';

/// Client for interacting with ULink API
class ULinkApiClient {
  final String baseUrl;
  final String? apiKey;
  final String? jwtToken;

  ULinkApiClient({
    required this.baseUrl,
    String? apiKey,
    String? jwtToken,
  })  : apiKey = apiKey ?? _loadApiKeyFromConfig(),
        jwtToken = jwtToken ?? _loadJwtTokenFromConfig();

  /// Load API key from config if not provided
  static String? _loadApiKeyFromConfig() {
    final config = ConfigManager.loadConfig();
    if (config?.auth?.type == AuthType.apiKey) {
      return config!.auth!.apiKey;
    }
    return null;
  }

  /// Load JWT token from config if not provided
  static String? _loadJwtTokenFromConfig() {
    final config = ConfigManager.loadConfig();
    if (config?.auth?.type == AuthType.jwt) {
      final auth = config!.auth!;
      // Check if token is valid and not expired
      if (AuthService.isTokenValid(auth)) {
        return auth.token;
      }
    }
    return null;
  }

  /// Get valid token, refreshing if needed
  Future<String?> _getValidToken() async {
    if (jwtToken != null) {
      return jwtToken;
    }

    // Try to get from config with refresh
    final config = ConfigManager.loadConfig();
    if (config?.auth?.type == AuthType.jwt) {
      final supabaseUrl = config!.supabaseUrl;
      final supabaseAnonKey = config.supabaseAnonKey;
      if (supabaseUrl != null && supabaseAnonKey != null) {
        return await AuthService.getValidToken(
          supabaseUrl: supabaseUrl,
          supabaseAnonKey: supabaseAnonKey,
        );
      }
    }

    return null;
  }

  /// Get project configuration
  Future<ProjectConfig> getProjectConfig(String projectId) async {
    final url = Uri.parse('$baseUrl/projects/$projectId');
    final headers = <String, String>{'Content-Type': 'application/json'};

    // Get valid token (may refresh if needed)
    final token = await _getValidToken();

    // Use JWT token if available, otherwise use API key
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    } else if (apiKey != null) {
      headers['x-app-key'] = apiKey!;
    } else {
      throw Exception(
        'Authentication required. Please run "ulink login" or provide --api-key.',
      );
    }

    final response = await http.get(url, headers: headers);

    if (response.statusCode == 401) {
      throw Exception(
        'Authentication failed. Please check your API key or JWT token.',
      );
    } else if (response.statusCode == 403) {
      throw Exception(
        'Access forbidden. You may not have permission to access this project.',
      );
    } else if (response.statusCode == 404) {
      throw Exception('Project not found. Please check the project ID.');
    } else if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch project configuration: ${response.statusCode} ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    // Extract configuration from project response
    final configuration = json['configuration'] as Map<String, dynamic>?;

    // If configuration is null, create an empty one (project might not be configured yet)
    final configData = configuration ?? <String, dynamic>{};

    // Get domains
    final domains = await getProjectDomains(projectId);

    // Convert DomainConfig list to list of maps for fromJson
    final domainsJson = domains
        .map((d) => <String, dynamic>{
              'id': d.id,
              'host': d.host,
              'status': d.status,
              'isPrimary': d.isPrimary,
            })
        .toList();

    return ProjectConfig.fromJson({
      'projectId': projectId,
      ...configData,
      'domains': domainsJson,
    });
  }

  /// Get a project by its slug
  Future<ProjectListItem> getProjectBySlug(String slug) async {
    final url = Uri.parse('$baseUrl/projects/by-slug/$slug');
    final headers = <String, String>{'Content-Type': 'application/json'};

    // Get valid token (may refresh if needed)
    final token = await _getValidToken();

    // Use JWT token if available, otherwise use API key
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    } else if (apiKey != null) {
      headers['x-app-key'] = apiKey!;
    } else {
      throw Exception(
        'Authentication required. Please run "ulink login" or provide --api-key.',
      );
    }

    final response = await http.get(url, headers: headers);

    if (response.statusCode == 401) {
      throw Exception(
        'Authentication failed. Please check your credentials. Run "ulink login" to re-authenticate.',
      );
    } else if (response.statusCode == 403) {
      throw Exception(
        'Access forbidden. You may not have permission to access this project.',
      );
    } else if (response.statusCode == 404) {
      throw Exception(
        'Project not found. Please check the project slug.',
      );
    } else if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch project: ${response.statusCode} ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return ProjectListItem.fromJson(json);
  }

  /// Get all projects for the authenticated user
  Future<List<ProjectListItem>> getProjects() async {
    final url = Uri.parse('$baseUrl/projects');
    final headers = <String, String>{'Content-Type': 'application/json'};

    // Get valid token (may refresh if needed)
    final token = await _getValidToken();

    // Use JWT token if available, otherwise use API key
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    } else if (apiKey != null) {
      headers['x-app-key'] = apiKey!;
    } else {
      throw Exception(
        'Authentication required. Please run "ulink login" or provide --api-key.',
      );
    }

    final response = await http.get(url, headers: headers);

    if (response.statusCode == 401) {
      throw Exception(
        'Authentication failed. Please check your credentials. Run "ulink login" to re-authenticate.',
      );
    } else if (response.statusCode == 403) {
      throw Exception(
        'Access forbidden. You may not have permission to access projects.',
      );
    } else if (response.statusCode == 404) {
      throw Exception(
        'Projects endpoint not found. Please check your API base URL: $baseUrl',
      );
    } else if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch projects: ${response.statusCode} ${response.body}',
      );
    }

    final json = jsonDecode(response.body);

    // Handle both array response and wrapped response
    List<dynamic> projectsList;
    if (json is List) {
      projectsList = json;
    } else if (json is Map && json['data'] is List) {
      projectsList = json['data'] as List<dynamic>;
    } else if (json is Map && json['projects'] is List) {
      projectsList = json['projects'] as List<dynamic>;
    } else {
      throw Exception('Unexpected response format from projects endpoint');
    }

    return projectsList
        .map((item) => ProjectListItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Get project domains
  Future<List<DomainConfig>> getProjectDomains(String projectId) async {
    final url = Uri.parse('$baseUrl/domains/projects/$projectId');
    final headers = <String, String>{'Content-Type': 'application/json'};

    // Get valid token (may refresh if needed)
    final token = await _getValidToken();

    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    } else if (apiKey != null) {
      headers['x-app-key'] = apiKey!;
    } else {
      // For domains, return empty list instead of throwing
      return [];
    }

    try {
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final body = response.body;
        List<dynamic> domainsList;

        // Response might be a list directly or wrapped in an object
        if (body.trim().startsWith('[')) {
          // Direct array response
          domainsList = jsonDecode(body) as List<dynamic>;
        } else {
          // Wrapped in object
          final json = jsonDecode(body) as Map<String, dynamic>;
          domainsList = json['data'] as List<dynamic>? ??
              json['domains'] as List<dynamic>? ??
              [];
        }

        return domainsList.map((d) {
          final domainJson = d as Map<String, dynamic>;
          // Map API response format to DomainConfig format
          // API returns 'verified' (boolean), CLI expects 'status' (string)
          final verified = domainJson['verified'] as bool? ?? false;
          final status = verified ? 'verified' : 'pending';

          return DomainConfig.fromJson({
            'id': domainJson['id'],
            'host': domainJson['host'],
            'status': status,
            'isPrimary': domainJson['isPrimary'] ?? false,
          });
        }).toList();
      } else if (response.statusCode == 401) {
        throw Exception(
          'Authentication failed. Please check your credentials.',
        );
      } else if (response.statusCode == 403) {
        throw Exception(
          'Access forbidden. You may not have permission to access domains for this project.',
        );
      } else if (response.statusCode == 404) {
        // Project not found or no domains - return empty list
        return [];
      }
    } catch (e) {
      // Log error but don't fail verification
      // If it's an auth error, rethrow it
      if (e.toString().contains('Authentication') ||
          e.toString().contains('forbidden')) {
        rethrow;
      }
      // For other errors, return empty list
    }

    return [];
  }

  /// Test API connection
  Future<bool> testConnection() async {
    try {
      final url = Uri.parse('$baseUrl/health');
      final response = await http.get(url);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Post verification results to the API for onboarding
  Future<void> postVerificationResults(
    String projectId,
    Map<String, dynamic> verificationReport,
  ) async {
    final url = Uri.parse('$baseUrl/projects/$projectId/onboarding/cli-verification');
    final headers = <String, String>{'Content-Type': 'application/json'};

    // Get valid token (may refresh if needed)
    final token = await _getValidToken();

    // Use JWT token if available, otherwise use API key
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    } else if (apiKey != null) {
      headers['x-app-key'] = apiKey!;
    } else {
      throw Exception(
        'Authentication required to upload verification results.',
      );
    }

    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode(verificationReport),
    );

    if (response.statusCode == 401) {
      throw Exception(
        'Authentication failed. Please check your credentials.',
      );
    } else if (response.statusCode == 403) {
      throw Exception(
        'Access forbidden. You may not have permission to update this project.',
      );
    } else if (response.statusCode == 404) {
      throw Exception('Project not found. Please check the project ID.');
    } else if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'Failed to upload verification results: ${response.statusCode}',
      );
    }
  }
}
