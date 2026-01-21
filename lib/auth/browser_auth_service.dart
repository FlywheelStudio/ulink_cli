import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import '../models/auth_config.dart';
import 'local_auth_server.dart';

/// Service for browser-based authentication
class BrowserAuthService {
  static const String _cliAuthPath = '/auth/cli';
  static const int _callbackPort = 43823;

  final String frontendUrl;
  final bool verbose;

  BrowserAuthService({
    required this.frontendUrl,
    this.verbose = false,
  });

  /// Generate a random string for PKCE code verifier
  static String _generateCodeVerifier() {
    final random = List<int>.generate(32, (i) => DateTime.now().microsecondsSinceEpoch % 256);
    return base64UrlEncode(random).replaceAll('=', '');
  }

  /// Generate SHA256 code challenge from verifier
  static String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  /// Authenticate using browser-based flow
  /// Returns AuthConfig on success, throws on error
  Future<AuthConfig> authenticate() async {
    // Generate unique session ID
    final sessionId = const Uuid().v4();

    // Generate PKCE code verifier and challenge
    final codeVerifier = _generateCodeVerifier();
    final codeChallenge = _generateCodeChallenge(codeVerifier);

    if (verbose) {
      print('Session ID: $sessionId');
      print('Code verifier generated');
      print('Code challenge: $codeChallenge');
    }

    // Build CLI auth URL
    final authUrl = _buildAuthUrl(sessionId, codeChallenge);

    // Start local server
    final server = LocalAuthServer(sessionId: sessionId);

    try {
      // Print instructions
      print('\nOpening browser for authentication...');
      print('If browser does not open, visit:');
      print('  $authUrl\n');

      // Try to open browser
      final opened = await _openBrowser(authUrl);
      if (!opened && verbose) {
        print('Could not automatically open browser');
      }

      // Wait for callback
      print('Waiting for authorization...');
      final result = await server.waitForCallback();

      if (!result.isSuccess) {
        throw Exception(result.error ?? 'Authentication failed');
      }

      // If we received tokens directly
      if (result.accessToken != null) {
        return _buildAuthConfigFromTokens(result);
      }

      // If we received an auth code, we would exchange it here
      // For now, we expect the frontend to send tokens directly
      // This simplifies the flow and avoids needing a backend token endpoint
      if (result.code != null) {
        // In a full implementation, exchange code for tokens
        // For now, we expect tokens directly
        throw Exception('Received auth code but token exchange not implemented');
      }

      throw Exception('No valid authentication data received');
    } finally {
      server.stop();
    }
  }

  /// Build the CLI authorization URL
  String _buildAuthUrl(String sessionId, String codeChallenge) {
    final params = {
      'session': sessionId,
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
      'callback_port': _callbackPort.toString(),
    };

    final queryString = params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');

    return '$frontendUrl$_cliAuthPath?$queryString';
  }

  /// Build AuthConfig from received tokens
  AuthConfig _buildAuthConfigFromTokens(AuthCallbackResult result) {
    final expiresAt = result.expiresIn != null
        ? DateTime.now().add(Duration(seconds: result.expiresIn!))
        : DateTime.now().add(const Duration(hours: 1));

    // Try to extract user info from the access token (JWT)
    UserInfo? userInfo;
    if (result.accessToken != null) {
      userInfo = _extractUserInfoFromToken(result.accessToken!);
    }

    return AuthConfig(
      type: AuthType.jwt,
      token: result.accessToken,
      refreshToken: result.refreshToken,
      expiresAt: expiresAt,
      user: userInfo,
    );
  }

  /// Extract user info from JWT token
  UserInfo? _extractUserInfoFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      // Decode the payload (second part)
      var payload = parts[1];
      // Add padding if needed
      while (payload.length % 4 != 0) {
        payload += '=';
      }

      final decoded = utf8.decode(base64Url.decode(payload));
      final claims = jsonDecode(decoded) as Map<String, dynamic>;

      return UserInfo(
        email: claims['email'] as String? ?? '',
        userId: claims['sub'] as String? ?? '',
      );
    } catch (e) {
      if (verbose) {
        print('Warning: Could not extract user info from token: $e');
      }
      return null;
    }
  }

  /// Try to open URL in default browser
  Future<bool> _openBrowser(String url) async {
    try {
      if (Platform.isMacOS) {
        final result = await Process.run('open', [url]);
        return result.exitCode == 0;
      } else if (Platform.isLinux) {
        final result = await Process.run('xdg-open', [url]);
        return result.exitCode == 0;
      } else if (Platform.isWindows) {
        final result = await Process.run('start', [url], runInShell: true);
        return result.exitCode == 0;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
