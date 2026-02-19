import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/auth_config.dart';
import 'config_manager.dart';

/// Service for Supabase authentication
class AuthService {
  /// Authenticate with email and password
  static Future<AuthConfig> loginWithEmailPassword({
    required String email,
    required String password,
    required String supabaseUrl,
    required String supabaseAnonKey,
  }) async {
    final url = Uri.parse('$supabaseUrl/auth/v1/token?grant_type=password');

    final response = await http.post(
      url,
      headers: {
        'apikey': supabaseAnonKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode != 200) {
      final errorBody = jsonDecode(response.body) as Map<String, dynamic>;
      final errorMessage = errorBody['error_description'] as String? ??
          errorBody['message'] as String? ??
          'Authentication failed';
      throw Exception(errorMessage);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final accessToken = data['access_token'] as String;
    final refreshToken = data['refresh_token'] as String?;
    final expiresIn = data['expires_in'] as int? ?? 3600;
    final user = data['user'] as Map<String, dynamic>?;

    final expiresAt = DateTime.now().add(Duration(seconds: expiresIn));

    return AuthConfig(
      type: AuthType.jwt,
      token: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
      user: user != null
          ? UserInfo(
              email: user['email'] as String? ?? email,
              userId: user['id'] as String? ?? '',
            )
          : null,
    );
  }

  /// Refresh access token using refresh token
  static Future<AuthConfig> refreshToken({
    required String refreshToken,
    required String supabaseUrl,
    required String supabaseAnonKey,
  }) async {
    final url =
        Uri.parse('$supabaseUrl/auth/v1/token?grant_type=refresh_token');

    final response = await http.post(
      url,
      headers: {
        'apikey': supabaseAnonKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'refresh_token': refreshToken,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Token refresh failed');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final accessToken = data['access_token'] as String;
    final newRefreshToken = data['refresh_token'] as String? ?? refreshToken;
    final expiresIn = data['expires_in'] as int? ?? 3600;
    final user = data['user'] as Map<String, dynamic>?;

    final expiresAt = DateTime.now().add(Duration(seconds: expiresIn));

    // Get existing auth to preserve user info
    final existingConfig = ConfigManager.loadConfig();
    final existingUser = existingConfig?.auth?.user;

    return AuthConfig(
      type: AuthType.jwt,
      token: accessToken,
      refreshToken: newRefreshToken,
      expiresAt: expiresAt,
      user: user != null
          ? UserInfo(
              email: user['email'] as String? ?? existingUser?.email ?? '',
              userId: user['id'] as String? ?? existingUser?.userId ?? '',
            )
          : existingUser,
    );
  }

  /// Validate token by checking expiration
  static bool isTokenValid(AuthConfig? auth) {
    if (auth == null) return false;
    if (auth.type == AuthType.apiKey) {
      return auth.apiKey != null;
    }
    if (auth.type == AuthType.jwt) {
      if (auth.token == null) return false;
      if (auth.isExpired) return false;
      return true;
    }
    return false;
  }

  /// Get valid token, refreshing proactively if expiring soon.
  ///
  /// Throws [Exception] with a descriptive message when refresh fails,
  /// so callers can display actionable guidance to the user.
  static Future<String?> getValidToken({
    String? supabaseUrl,
    String? supabaseAnonKey,
  }) async {
    final config = ConfigManager.loadConfig();
    final auth = config?.auth;

    if (auth == null) return null;

    if (auth.type == AuthType.apiKey) {
      return auth.apiKey;
    }

    if (auth.type == AuthType.jwt) {
      // Proactive refresh: refresh if expired OR expiring within 5 minutes
      if ((auth.isExpired || auth.isExpiringSoon) &&
          auth.refreshToken != null) {
        if (supabaseUrl != null && supabaseAnonKey != null) {
          // Retry once on transient failures
          Exception? lastError;
          for (var attempt = 0; attempt < 2; attempt++) {
            try {
              final refreshed = await refreshToken(
                refreshToken: auth.refreshToken!,
                supabaseUrl: supabaseUrl,
                supabaseAnonKey: supabaseAnonKey,
              );
              await ConfigManager.updateAuth(refreshed);
              return refreshed.token;
            } catch (e) {
              lastError = e is Exception ? e : Exception('$e');
              if (attempt == 0) continue; // retry once
            }
          }
          // Both attempts failed
          throw Exception(
            'Session expired and token refresh failed. '
            'Please run "ulink login" to re-authenticate.\n'
            'Reason: $lastError',
          );
        }
        // No Supabase credentials available for refresh
        throw Exception(
          'Session expired. Please run "ulink login" to re-authenticate.',
        );
      }

      return auth.token;
    }

    return null;
  }
}
