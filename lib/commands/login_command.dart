import 'dart:io';
import '../auth/auth_service.dart';
import '../auth/browser_auth_service.dart';
import '../auth/config_manager.dart';
import '../models/auth_config.dart';
import '../config/constants.dart';

/// Command for logging in to ULink
class LoginCommand {
  final bool verbose;
  final String baseUrl;

  LoginCommand({this.verbose = false, this.baseUrl = 'https://api.ulink.ly'});

  /// Execute login
  Future<void> execute({bool useApiKey = false, bool usePassword = false}) async {
    // Check if already logged in with a valid (non-expired) session
    if (ConfigManager.isLoggedIn()) {
      final config = ConfigManager.loadConfig();
      final auth = config?.auth;

      // If token is expired, allow re-authentication instead of blocking
      final isExpired = auth?.type == AuthType.jwt && auth!.isExpired;
      if (isExpired) {
        print('⚠ Session expired for ${auth.user?.email ?? 'unknown'}. Re-authenticating...\n');
      } else if (auth?.type == AuthType.jwt && auth!.user != null) {
        print('✓ Already logged in as ${auth.user!.email}');
        print(
            'Run "ulink logout" to log out first if you want to login with a different account.');
        return;
      } else if (auth?.type == AuthType.apiKey) {
        print('✓ Already logged in with API key');
        print(
            'Run "ulink logout" to log out first if you want to login with a different account.');
        return;
      }
    }

    try {
      if (useApiKey) {
        await _loginWithApiKey();
      } else if (usePassword) {
        await _loginWithEmailPassword();
      } else {
        // Browser login is the default
        await _loginWithBrowser();
      }
    } catch (e) {
      stderr.writeln('Login failed: $e');
      exit(1);
    }
  }

  /// Login using browser-based authentication
  Future<void> _loginWithBrowser() async {
    print('🔐 ULink CLI Login (Browser)\n');

    // Use embedded Supabase configuration
    String supabaseUrl = ULinkConstants.supabaseUrl;
    String supabaseAnonKey = ULinkConstants.supabaseAnonKey;

    // Allow override via environment variables for development
    final envUrl = Platform.environment['SUPABASE_URL'];
    final envKey = Platform.environment['SUPABASE_ANON_KEY'];
    if (envUrl != null && envUrl.isNotEmpty) {
      supabaseUrl = envUrl;
      if (verbose) {
        print('Using Supabase URL from environment variable');
      }
    }
    if (envKey != null && envKey.isNotEmpty) {
      supabaseAnonKey = envKey;
      if (verbose) {
        print('Using Supabase anon key from environment variable');
      }
    }

    // Get frontend URL - default to production, allow override
    final frontendUrl = Platform.environment['ULINK_FRONTEND_URL'] ?? 'https://ulink.ly';

    final browserAuth = BrowserAuthService(
      frontendUrl: frontendUrl,
      verbose: verbose,
    );

    try {
      final auth = await browserAuth.authenticate();

      // Save Supabase config
      await ConfigManager.updateSupabaseConfig(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );

      // Save auth
      await ConfigManager.updateAuth(auth);

      print('\n✓ Successfully logged in as ${auth.user?.email ?? 'unknown'}');
    } catch (e) {
      stderr.writeln('\n✗ Authentication failed: $e');
      exit(1);
    }
  }

  /// Login with email and password
  Future<void> _loginWithEmailPassword() async {
    print('🔐 ULink CLI Login\n');

    // Use embedded Supabase configuration (embedded in binary for security)
    // Fallback to environment variables for development/testing
    String supabaseUrl = ULinkConstants.supabaseUrl;
    String supabaseAnonKey = ULinkConstants.supabaseAnonKey;

    // Allow override via environment variables for development
    final envUrl = Platform.environment['SUPABASE_URL'];
    final envKey = Platform.environment['SUPABASE_ANON_KEY'];
    if (envUrl != null && envUrl.isNotEmpty) {
      supabaseUrl = envUrl;
      if (verbose) {
        print('Using Supabase URL from environment variable');
      }
    }
    if (envKey != null && envKey.isNotEmpty) {
      supabaseAnonKey = envKey;
      if (verbose) {
        print('Using Supabase anon key from environment variable');
      }
    }

    // Prompt for email
    stdout.write('Email: ');
    final email = stdin.readLineSync()?.trim();
    if (email == null || email.isEmpty) {
      stderr.writeln('Error: Email is required');
      exit(1);
    }

    // Prompt for password (hidden input)
    stdout.write('Password: ');
    final password = _readPassword();
    if (password == null || password.isEmpty) {
      stderr.writeln('Error: Password is required');
      exit(1);
    }
    print(''); // New line after password input

    // Authenticate
    print('Authenticating...');
    try {
      final auth = await AuthService.loginWithEmailPassword(
        email: email,
        password: password,
        supabaseUrl: supabaseUrl,
        supabaseAnonKey: supabaseAnonKey,
      );

      // Save Supabase config
      await ConfigManager.updateSupabaseConfig(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );

      // Save auth
      await ConfigManager.updateAuth(auth);

      print('✓ Successfully logged in as ${auth.user?.email ?? email}');
    } catch (e) {
      stderr.writeln('✗ Authentication failed: $e');
      exit(1);
    }
  }

  /// Login with API key
  Future<void> _loginWithApiKey() async {
    print('🔑 ULink CLI Login (API Key)\n');

    stdout.write('API Key: ');
    final apiKey = _readPassword(); // Use password input to hide API key
    if (apiKey == null || apiKey.isEmpty) {
      stderr.writeln('Error: API key is required');
      exit(1);
    }
    print(''); // New line after input

    // Create auth config with API key
    final auth = AuthConfig(
      type: AuthType.apiKey,
      apiKey: apiKey,
    );

    // Save auth
    await ConfigManager.updateAuth(auth);

    print('✓ API key stored successfully');
  }

  /// Read password with hidden input (basic implementation)
  String? _readPassword() {
    // For now, use regular input
    // In a production CLI, you might want to use a package like 'password' or platform-specific code
    // to hide the input, but for simplicity, we'll use regular input
    return stdin.readLineSync()?.trim();
  }
}
