import 'dart:async';
import 'dart:io';

/// Result from the local auth server callback
class AuthCallbackResult {
  final String? code;
  final String? accessToken;
  final String? refreshToken;
  final int? expiresIn;
  final String? error;
  final String? session;

  AuthCallbackResult({
    this.code,
    this.accessToken,
    this.refreshToken,
    this.expiresIn,
    this.error,
    this.session,
  });

  bool get isSuccess => (code != null || accessToken != null) && error == null;
}

/// Local HTTP server for receiving OAuth callbacks
class LocalAuthServer {
  static const int _port = 43823;
  static const Duration _timeout = Duration(minutes: 5);

  HttpServer? _server;
  Timer? _timeoutTimer;
  final String _expectedSession;
  final Completer<AuthCallbackResult> _completer = Completer();

  LocalAuthServer({required String sessionId}) : _expectedSession = sessionId;

  /// Start the server and wait for callback
  Future<AuthCallbackResult> waitForCallback() async {
    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, _port);

      // Set up timeout
      _timeoutTimer = Timer(_timeout, () {
        if (!_completer.isCompleted) {
          _completer.complete(AuthCallbackResult(
            error: 'Authentication timed out after 5 minutes',
          ));
          stop();
        }
      });

      // Listen for requests
      await for (final request in _server!) {
        if (_completer.isCompleted) break;

        if (request.uri.path == '/callback') {
          await _handleCallback(request);
          break;
        } else {
          // Unknown route
          request.response
            ..statusCode = HttpStatus.notFound
            ..headers.contentType = ContentType.html
            ..write(_buildErrorHtml('Unknown route'));
          await request.response.close();
        }
      }
    } catch (e) {
      if (!_completer.isCompleted) {
        _completer.complete(AuthCallbackResult(error: e.toString()));
      }
    }

    return _completer.future;
  }

  /// Handle the callback request
  Future<void> _handleCallback(HttpRequest request) async {
    final params = request.uri.queryParameters;

    // Check for error
    final error = params['error'];
    if (error != null) {
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.html
        ..write(_buildErrorHtml(params['error_description'] ?? error));
      await request.response.close();

      if (!_completer.isCompleted) {
        _completer.complete(AuthCallbackResult(
          error: params['error_description'] ?? error,
        ));
      }
      return;
    }

    // Verify session matches
    final session = params['session'];
    if (session != _expectedSession) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..headers.contentType = ContentType.html
        ..write(_buildErrorHtml('Session mismatch'));
      await request.response.close();

      if (!_completer.isCompleted) {
        _completer.complete(AuthCallbackResult(
          error: 'Session mismatch - possible security issue',
        ));
      }
      return;
    }

    // Get tokens - could be auth code or direct tokens
    final code = params['code'];
    final accessToken = params['access_token'];
    final refreshToken = params['refresh_token'];
    final expiresInStr = params['expires_in'];
    final expiresIn = expiresInStr != null ? int.tryParse(expiresInStr) : null;

    if (code == null && accessToken == null) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..headers.contentType = ContentType.html
        ..write(_buildErrorHtml('No authorization code or token received'));
      await request.response.close();

      if (!_completer.isCompleted) {
        _completer.complete(AuthCallbackResult(
          error: 'No authorization code or token received',
        ));
      }
      return;
    }

    // Success!
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.html
      ..write(_buildSuccessHtml());
    await request.response.close();

    if (!_completer.isCompleted) {
      _completer.complete(AuthCallbackResult(
        code: code,
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresIn: expiresIn,
        session: session,
      ));
    }
  }

  /// Stop the server
  void stop() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    _server?.close(force: true);
    _server = null;
  }

  /// Build success HTML page
  String _buildSuccessHtml() {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>ULink CLI - Authenticated</title>
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 20px;
    }
    .container {
      background: white;
      border-radius: 16px;
      padding: 48px;
      text-align: center;
      box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
      max-width: 400px;
      width: 100%;
    }
    .icon {
      width: 80px;
      height: 80px;
      background: #10b981;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      margin: 0 auto 24px;
    }
    .icon svg {
      width: 40px;
      height: 40px;
      fill: white;
    }
    h1 {
      color: #1f2937;
      font-size: 24px;
      margin-bottom: 12px;
    }
    p {
      color: #6b7280;
      font-size: 16px;
      line-height: 1.5;
    }
    .close-note {
      margin-top: 24px;
      padding-top: 24px;
      border-top: 1px solid #e5e7eb;
      color: #9ca3af;
      font-size: 14px;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="icon">
      <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
        <path d="M9 12L11 14L15 10M21 12C21 16.9706 16.9706 21 12 21C7.02944 21 3 16.9706 3 12C3 7.02944 7.02944 3 12 3C16.9706 3 21 7.02944 21 12Z" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
      </svg>
    </div>
    <h1>Authentication Successful!</h1>
    <p>You have been successfully authenticated with the ULink CLI.</p>
    <p class="close-note">You can close this window and return to your terminal.</p>
  </div>
  <script>
    // Auto-close after 3 seconds
    setTimeout(() => {
      window.close();
    }, 3000);
  </script>
</body>
</html>
''';
  }

  /// Build error HTML page
  String _buildErrorHtml(String message) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>ULink CLI - Authentication Failed</title>
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 20px;
    }
    .container {
      background: white;
      border-radius: 16px;
      padding: 48px;
      text-align: center;
      box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
      max-width: 400px;
      width: 100%;
    }
    .icon {
      width: 80px;
      height: 80px;
      background: #ef4444;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      margin: 0 auto 24px;
    }
    .icon svg {
      width: 40px;
      height: 40px;
      fill: white;
    }
    h1 {
      color: #1f2937;
      font-size: 24px;
      margin-bottom: 12px;
    }
    p {
      color: #6b7280;
      font-size: 16px;
      line-height: 1.5;
    }
    .error-message {
      background: #fef2f2;
      border: 1px solid #fecaca;
      border-radius: 8px;
      padding: 12px;
      margin-top: 16px;
      color: #dc2626;
      font-size: 14px;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="icon">
      <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
        <path d="M6 18L18 6M6 6L18 18" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
      </svg>
    </div>
    <h1>Authentication Failed</h1>
    <p>There was a problem authenticating with the ULink CLI.</p>
    <div class="error-message">$message</div>
  </div>
</body>
</html>
''';
  }
}
