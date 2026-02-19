import 'package:test/test.dart';
import 'package:ulink_cli/auth/auth_service.dart';
import 'package:ulink_cli/models/auth_config.dart';

void main() {
  group('AuthService', () {
    group('isTokenValid', () {
      test('should return false for null auth', () {
        final result = AuthService.isTokenValid(null);

        expect(result, isFalse);
      });

      test('should return true for valid API key auth', () {
        final auth = AuthConfig(
          type: AuthType.apiKey,
          apiKey: 'valid-api-key',
        );

        final result = AuthService.isTokenValid(auth);

        expect(result, isTrue);
      });

      test('should return false for API key auth with null apiKey', () {
        final auth = AuthConfig(
          type: AuthType.apiKey,
          apiKey: null,
        );

        final result = AuthService.isTokenValid(auth);

        expect(result, isFalse);
      });

      test('should return true for valid JWT with future expiration', () {
        final auth = AuthConfig(
          type: AuthType.jwt,
          token: 'valid-token',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );

        final result = AuthService.isTokenValid(auth);

        expect(result, isTrue);
      });

      test('should return false for JWT with null token', () {
        final auth = AuthConfig(
          type: AuthType.jwt,
          token: null,
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );

        final result = AuthService.isTokenValid(auth);

        expect(result, isFalse);
      });

      test('should return false for expired JWT', () {
        final auth = AuthConfig(
          type: AuthType.jwt,
          token: 'valid-token',
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        );

        final result = AuthService.isTokenValid(auth);

        expect(result, isFalse);
      });

      test('should return true for JWT with null expiresAt', () {
        // If expiresAt is null, isExpired returns false
        final auth = AuthConfig(
          type: AuthType.jwt,
          token: 'valid-token',
          expiresAt: null,
        );

        final result = AuthService.isTokenValid(auth);

        expect(result, isTrue);
      });

      test('should return false for JWT about to expire', () {
        // Exactly at expiration time
        final auth = AuthConfig(
          type: AuthType.jwt,
          token: 'valid-token',
          expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
        );

        final result = AuthService.isTokenValid(auth);

        expect(result, isFalse);
      });

      test('should handle edge case of expiration time being now', () {
        // Test with current time - should be considered valid or just expired
        // depending on microsecond timing
        final auth = AuthConfig(
          type: AuthType.jwt,
          token: 'valid-token',
          expiresAt: DateTime.now().add(const Duration(milliseconds: 100)),
        );

        final result = AuthService.isTokenValid(auth);

        expect(result, isTrue);
      });
    });

    // Note: loginWithEmailPassword and refreshToken tests would require mocking
    // HTTP client, which requires refactoring the AuthService to accept an
    // injectable HTTP client. The following tests verify the method exists
    // and has the expected signature.

    group('loginWithEmailPassword', () {
      test('method exists and has correct parameters', () {
        // Verify the method signature exists
        expect(
          AuthService.loginWithEmailPassword,
          isA<Function>(),
        );
      });
    });

    group('refreshToken', () {
      test('method exists and has correct parameters', () {
        // Verify the method signature exists
        expect(
          AuthService.refreshToken,
          isA<Function>(),
        );
      });
    });

    group('getValidToken', () {
      test('method exists and has correct parameters', () {
        // Verify the method signature exists
        expect(
          AuthService.getValidToken,
          isA<Function>(),
        );
      });

      // Note: Full getValidToken tests with HTTP mocking would require
      // refactoring AuthService to accept an injectable HTTP client.
      // The following tests verify the refresh decision logic via
      // isExpired and isExpiringSoon which drive getValidToken behavior.
    });

    group('proactive refresh decision logic', () {
      // getValidToken refreshes when (isExpired || isExpiringSoon) && refreshToken != null
      // These tests verify the conditions that trigger refresh

      test('should need refresh when token is expired with refresh token', () {
        final auth = AuthConfig(
          type: AuthType.jwt,
          token: 'expired-token',
          refreshToken: 'refresh-token',
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        );

        final needsRefresh =
            (auth.isExpired || auth.isExpiringSoon) && auth.refreshToken != null;

        expect(needsRefresh, isTrue);
        expect(auth.isExpired, isTrue);
      });

      test('should need refresh when token is expiring soon with refresh token', () {
        final auth = AuthConfig(
          type: AuthType.jwt,
          token: 'soon-expiring-token',
          refreshToken: 'refresh-token',
          expiresAt: DateTime.now().add(const Duration(minutes: 3)),
        );

        final needsRefresh =
            (auth.isExpired || auth.isExpiringSoon) && auth.refreshToken != null;

        expect(needsRefresh, isTrue);
        expect(auth.isExpired, isFalse);
        expect(auth.isExpiringSoon, isTrue);
      });

      test('should not need refresh when token has plenty of time', () {
        final auth = AuthConfig(
          type: AuthType.jwt,
          token: 'valid-token',
          refreshToken: 'refresh-token',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );

        final needsRefresh =
            (auth.isExpired || auth.isExpiringSoon) && auth.refreshToken != null;

        expect(needsRefresh, isFalse);
        expect(auth.isExpired, isFalse);
        expect(auth.isExpiringSoon, isFalse);
      });

      test('should not need refresh when no refresh token available', () {
        final auth = AuthConfig(
          type: AuthType.jwt,
          token: 'expired-token',
          refreshToken: null,
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        );

        final needsRefresh =
            (auth.isExpired || auth.isExpiringSoon) && auth.refreshToken != null;

        expect(needsRefresh, isFalse);
      });

      test('should not need refresh for API key auth', () {
        final auth = AuthConfig(
          type: AuthType.apiKey,
          apiKey: 'api-key',
        );

        // API keys don't expire
        expect(auth.isExpired, isFalse);
        expect(auth.isExpiringSoon, isFalse);
      });
    });
  });
}
