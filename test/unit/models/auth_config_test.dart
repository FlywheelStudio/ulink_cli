import 'package:test/test.dart';
import 'package:ulink_cli/models/auth_config.dart';

void main() {
  group('AuthConfig', () {
    group('fromJson', () {
      test('should parse JWT auth config', () {
        final json = {
          'type': 'jwt',
          'token': 'test-token',
          'refreshToken': 'refresh-token',
          'expiresAt': '2024-12-31T23:59:59.000Z',
          'user': {
            'email': 'test@example.com',
            'userId': 'user-123',
          },
        };

        final config = AuthConfig.fromJson(json);

        expect(config.type, AuthType.jwt);
        expect(config.token, 'test-token');
        expect(config.refreshToken, 'refresh-token');
        expect(config.expiresAt, isNotNull);
        expect(config.user?.email, 'test@example.com');
        expect(config.user?.userId, 'user-123');
      });

      test('should parse API key auth config', () {
        final json = {
          'type': 'apiKey',
          'apiKey': 'api-key-123',
        };

        final config = AuthConfig.fromJson(json);

        expect(config.type, AuthType.apiKey);
        expect(config.apiKey, 'api-key-123');
        expect(config.token, isNull);
      });

      test('should default to apiKey for unknown type', () {
        final json = {
          'type': 'unknown',
          'apiKey': 'key',
        };

        final config = AuthConfig.fromJson(json);

        expect(config.type, AuthType.apiKey);
      });

      test('should handle missing optional fields', () {
        final json = {
          'type': 'jwt',
          'token': 'token',
        };

        final config = AuthConfig.fromJson(json);

        expect(config.type, AuthType.jwt);
        expect(config.token, 'token');
        expect(config.refreshToken, isNull);
        expect(config.expiresAt, isNull);
        expect(config.user, isNull);
      });
    });

    group('toJson', () {
      test('should serialize JWT auth config', () {
        final config = AuthConfig(
          type: AuthType.jwt,
          token: 'test-token',
          refreshToken: 'refresh-token',
          expiresAt: DateTime.utc(2024, 12, 31, 23, 59, 59),
          user: UserInfo(email: 'test@example.com', userId: 'user-123'),
        );

        final json = config.toJson();

        expect(json['type'], 'jwt');
        expect(json['token'], 'test-token');
        expect(json['refreshToken'], 'refresh-token');
        expect(json['expiresAt'], isNotNull);
        expect(json['user']['email'], 'test@example.com');
      });

      test('should serialize API key auth config', () {
        final config = AuthConfig(
          type: AuthType.apiKey,
          apiKey: 'api-key-123',
        );

        final json = config.toJson();

        expect(json['type'], 'apiKey');
        expect(json['apiKey'], 'api-key-123');
        expect(json.containsKey('token'), isFalse);
      });

      test('should not include null optional fields', () {
        final config = AuthConfig(
          type: AuthType.jwt,
          token: 'token',
        );

        final json = config.toJson();

        expect(json.containsKey('refreshToken'), isFalse);
        expect(json.containsKey('expiresAt'), isFalse);
        expect(json.containsKey('user'), isFalse);
      });
    });

    group('isExpired', () {
      test('should return false when expiresAt is null', () {
        final config = AuthConfig(
          type: AuthType.jwt,
          token: 'token',
          expiresAt: null,
        );

        expect(config.isExpired, isFalse);
      });

      test('should return true when expired', () {
        final config = AuthConfig(
          type: AuthType.jwt,
          token: 'token',
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        );

        expect(config.isExpired, isTrue);
      });

      test('should return false when not expired', () {
        final config = AuthConfig(
          type: AuthType.jwt,
          token: 'token',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );

        expect(config.isExpired, isFalse);
      });
    });
  });

  group('UserInfo', () {
    group('fromJson', () {
      test('should parse user info', () {
        final json = {
          'email': 'test@example.com',
          'userId': 'user-123',
        };

        final user = UserInfo.fromJson(json);

        expect(user.email, 'test@example.com');
        expect(user.userId, 'user-123');
      });
    });

    group('toJson', () {
      test('should serialize user info', () {
        final user = UserInfo(email: 'test@example.com', userId: 'user-123');

        final json = user.toJson();

        expect(json['email'], 'test@example.com');
        expect(json['userId'], 'user-123');
      });
    });
  });

  group('ProjectInfo', () {
    group('fromJson', () {
      test('should parse project info', () {
        final json = {
          'projectId': 'proj-123',
          'projectName': 'Test Project',
          'apiKey': 'api-key',
        };

        final project = ProjectInfo.fromJson(json);

        expect(project.projectId, 'proj-123');
        expect(project.projectName, 'Test Project');
        expect(project.apiKey, 'api-key');
      });

      test('should handle missing optional apiKey', () {
        final json = {
          'projectId': 'proj-123',
          'projectName': 'Test Project',
        };

        final project = ProjectInfo.fromJson(json);

        expect(project.projectId, 'proj-123');
        expect(project.apiKey, isNull);
      });
    });

    group('toJson', () {
      test('should serialize project info', () {
        final project = ProjectInfo(
          projectId: 'proj-123',
          projectName: 'Test Project',
          apiKey: 'api-key',
        );

        final json = project.toJson();

        expect(json['projectId'], 'proj-123');
        expect(json['projectName'], 'Test Project');
        expect(json['apiKey'], 'api-key');
      });

      test('should not include null apiKey', () {
        final project = ProjectInfo(
          projectId: 'proj-123',
          projectName: 'Test Project',
        );

        final json = project.toJson();

        expect(json.containsKey('apiKey'), isFalse);
      });
    });
  });

  group('CliConfig', () {
    group('fromJson', () {
      test('should parse full CLI config', () {
        final json = {
          'auth': {
            'type': 'jwt',
            'token': 'token',
          },
          'projects': [
            {
              'projectId': 'proj-1',
              'projectName': 'Project 1',
            },
          ],
          'supabaseUrl': 'https://supabase.example.com',
          'supabaseAnonKey': 'anon-key',
        };

        final config = CliConfig.fromJson(json);

        expect(config.auth?.type, AuthType.jwt);
        expect(config.projects.length, 1);
        expect(config.projects[0].projectId, 'proj-1');
        expect(config.supabaseUrl, 'https://supabase.example.com');
        expect(config.supabaseAnonKey, 'anon-key');
      });

      test('should handle empty config', () {
        final json = <String, dynamic>{};

        final config = CliConfig.fromJson(json);

        expect(config.auth, isNull);
        expect(config.projects, isEmpty);
        expect(config.supabaseUrl, isNull);
      });
    });

    group('toJson', () {
      test('should serialize CLI config', () {
        final config = CliConfig(
          auth: AuthConfig(type: AuthType.apiKey, apiKey: 'key'),
          projects: [
            ProjectInfo(projectId: 'proj-1', projectName: 'Project 1'),
          ],
          supabaseUrl: 'https://supabase.example.com',
        );

        final json = config.toJson();

        expect(json['auth']['type'], 'apiKey');
        expect(json['projects'].length, 1);
        expect(json['supabaseUrl'], 'https://supabase.example.com');
      });
    });
  });
}
