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
  final String? _explicitApiKey;
  final String? _explicitJwtToken;

  ULinkApiClient({
    required this.baseUrl,
    String? apiKey,
    String? jwtToken,
  })  : _explicitApiKey = apiKey,
        _explicitJwtToken = jwtToken;

  /// Get API key from explicit param or config
  String? get apiKey {
    if (_explicitApiKey != null) return _explicitApiKey;
    final config = ConfigManager.loadConfig();
    if (config?.auth?.type == AuthType.apiKey) {
      return config!.auth!.apiKey;
    }
    return null;
  }

  /// Get valid token, refreshing if needed.
  /// Always attempts async refresh — never uses a stale cached token.
  Future<String?> _getValidToken() async {
    // If an explicit JWT was passed to the constructor, use it directly
    if (_explicitJwtToken != null) {
      return _explicitJwtToken;
    }

    // Load from config with async refresh support
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
      // No Supabase credentials — return token as-is if not expired
      final auth = config.auth!;
      if (!auth.isExpired) return auth.token;
    }

    return null;
  }

  /// Build auth headers, throwing if no auth is available
  Future<Map<String, String>> _authHeaders() async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final token = await _getValidToken();
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    } else if (apiKey != null) {
      headers['x-app-key'] = apiKey!;
    } else {
      throw Exception(
        'Authentication required. Please run "ulink login" or provide --api-key.',
      );
    }
    return headers;
  }

  /// Force-refresh the token and return updated auth headers.
  /// Used when a request returns 401 to retry once with a fresh token.
  Future<Map<String, String>?> _refreshAndBuildHeaders() async {
    if (_explicitJwtToken != null || _explicitApiKey != null) return null;

    final config = ConfigManager.loadConfig();
    if (config?.auth?.type != AuthType.jwt) return null;

    final auth = config!.auth!;
    if (auth.refreshToken == null) return null;

    final supabaseUrl = config.supabaseUrl;
    final supabaseAnonKey = config.supabaseAnonKey;
    if (supabaseUrl == null || supabaseAnonKey == null) return null;

    try {
      final refreshed = await AuthService.refreshToken(
        refreshToken: auth.refreshToken!,
        supabaseUrl: supabaseUrl,
        supabaseAnonKey: supabaseAnonKey,
      );
      await ConfigManager.updateAuth(refreshed);
      return <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${refreshed.token}',
      };
    } catch (_) {
      return null;
    }
  }

  /// Execute a GET request with automatic 401 retry
  Future<http.Response> _getWithRetry(Uri url, Map<String, String> headers) async {
    var response = await http.get(url, headers: headers);
    if (response.statusCode == 401) {
      final retryHeaders = await _refreshAndBuildHeaders();
      if (retryHeaders != null) {
        response = await http.get(url, headers: retryHeaders);
      }
    }
    return response;
  }

  /// Execute a POST request with automatic 401 retry
  Future<http.Response> _postWithRetry(
    Uri url,
    Map<String, String> headers,
    String body,
  ) async {
    var response = await http.post(url, headers: headers, body: body);
    if (response.statusCode == 401) {
      final retryHeaders = await _refreshAndBuildHeaders();
      if (retryHeaders != null) {
        response = await http.post(url, headers: retryHeaders, body: body);
      }
    }
    return response;
  }

  /// Get project configuration
  Future<ProjectConfig> getProjectConfig(String projectId) async {
    final url = Uri.parse('$baseUrl/projects/$projectId');
    final headers = await _authHeaders();

    final response = await _getWithRetry(url, headers);

    if (response.statusCode == 401) {
      throw Exception(
        'Authentication failed. Please run "ulink login" to re-authenticate.',
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
    final headers = await _authHeaders();

    final response = await _getWithRetry(url, headers);

    if (response.statusCode == 401) {
      throw Exception(
        'Authentication failed. Please run "ulink login" to re-authenticate.',
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
    final headers = await _authHeaders();

    final response = await _getWithRetry(url, headers);

    if (response.statusCode == 401) {
      throw Exception(
        'Authentication failed. Please run "ulink login" to re-authenticate.',
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

    Map<String, String> headers;
    try {
      headers = await _authHeaders();
    } catch (_) {
      // For domains, return empty list instead of throwing
      return [];
    }

    try {
      final response = await _getWithRetry(url, headers);

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
          'Authentication failed. Please run "ulink login" to re-authenticate.',
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
    final headers = await _authHeaders();

    final response = await _postWithRetry(
      url,
      headers,
      jsonEncode(verificationReport),
    );

    if (response.statusCode == 401) {
      throw Exception(
        'Authentication failed. Please run "ulink login" to re-authenticate.',
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
