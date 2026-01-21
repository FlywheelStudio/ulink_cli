import 'package:test/test.dart';
import 'package:ulink_cli/models/project_config.dart';

void main() {
  group('ProjectConfig', () {
    group('fromJson', () {
      test('should parse full project config', () {
        final json = {
          'projectId': 'proj-123',
          'ios_bundle_identifier': 'com.example.app',
          'ios_team_id': 'ABC123DEFG',
          'ios_deeplink_schema': 'myapp://',
          'android_package_name': 'com.example.app',
          'android_sha256_fingerprints': [
            'AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99',
          ],
          'android_deeplink_schema': 'myapp://',
          'domains': [
            {
              'id': 'domain-1',
              'host': 'example.com',
              'status': 'verified',
              'isPrimary': true,
            },
          ],
        };

        final config = ProjectConfig.fromJson(json);

        expect(config.projectId, 'proj-123');
        expect(config.iosBundleIdentifier, 'com.example.app');
        expect(config.iosTeamId, 'ABC123DEFG');
        expect(config.iosDeeplinkSchema, 'myapp://');
        expect(config.androidPackageName, 'com.example.app');
        expect(config.androidSha256Fingerprints.length, 1);
        expect(config.androidDeeplinkSchema, 'myapp://');
        expect(config.domains.length, 1);
        expect(config.domains[0].host, 'example.com');
      });

      test('should handle missing optional fields', () {
        final json = {
          'projectId': 'proj-123',
        };

        final config = ProjectConfig.fromJson(json);

        expect(config.projectId, 'proj-123');
        expect(config.iosBundleIdentifier, isNull);
        expect(config.iosTeamId, isNull);
        expect(config.androidPackageName, isNull);
        expect(config.androidSha256Fingerprints, isEmpty);
        expect(config.domains, isEmpty);
      });

      test('should parse empty fingerprints array', () {
        final json = {
          'projectId': 'proj-123',
          'android_sha256_fingerprints': <dynamic>[],
        };

        final config = ProjectConfig.fromJson(json);

        expect(config.androidSha256Fingerprints, isEmpty);
      });

      test('should parse null fingerprints as empty list', () {
        final json = {
          'projectId': 'proj-123',
          'android_sha256_fingerprints': null,
        };

        final config = ProjectConfig.fromJson(json);

        expect(config.androidSha256Fingerprints, isEmpty);
      });

      test('should parse multiple domains', () {
        final json = {
          'projectId': 'proj-123',
          'domains': [
            {
              'id': 'domain-1',
              'host': 'example.com',
              'status': 'verified',
            },
            {
              'id': 'domain-2',
              'host': 'test.example.com',
              'status': 'pending',
            },
            {
              'id': 'domain-3',
              'host': 'api.example.com',
              'status': 'failed',
            },
          ],
        };

        final config = ProjectConfig.fromJson(json);

        expect(config.domains.length, 3);
        expect(config.domains[0].status, 'verified');
        expect(config.domains[1].status, 'pending');
        expect(config.domains[2].status, 'failed');
      });

      test('should parse multiple fingerprints', () {
        final json = {
          'projectId': 'proj-123',
          'android_sha256_fingerprints': [
            'AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99',
            'FF:EE:DD:CC:BB:AA:99:88:77:66:55:44:33:22:11:00:FF:EE:DD:CC:BB:AA:99:88:77:66:55:44:33:22:11:00',
          ],
        };

        final config = ProjectConfig.fromJson(json);

        expect(config.androidSha256Fingerprints.length, 2);
      });
    });

    test('should create config with constructor', () {
      final config = ProjectConfig(
        projectId: 'proj-123',
        iosBundleIdentifier: 'com.example.app',
        androidPackageName: 'com.example.app',
        domains: [
          DomainConfig(id: 'd1', host: 'example.com', status: 'verified'),
        ],
      );

      expect(config.projectId, 'proj-123');
      expect(config.iosBundleIdentifier, 'com.example.app');
      expect(config.domains.length, 1);
    });
  });

  group('DomainConfig', () {
    group('fromJson', () {
      test('should parse domain config', () {
        final json = {
          'id': 'domain-1',
          'host': 'example.com',
          'status': 'verified',
          'isPrimary': true,
        };

        final domain = DomainConfig.fromJson(json);

        expect(domain.id, 'domain-1');
        expect(domain.host, 'example.com');
        expect(domain.status, 'verified');
        expect(domain.isPrimary, isTrue);
      });

      test('should default isPrimary to false', () {
        final json = {
          'id': 'domain-1',
          'host': 'example.com',
          'status': 'verified',
        };

        final domain = DomainConfig.fromJson(json);

        expect(domain.isPrimary, isFalse);
      });

      test('should default status to pending when null', () {
        final json = {
          'id': 'domain-1',
          'host': 'example.com',
          'status': null,
        };

        final domain = DomainConfig.fromJson(json);

        expect(domain.status, 'pending');
      });

      test('should parse different status values', () {
        final verifiedJson = {
          'id': 'd1',
          'host': 'example.com',
          'status': 'verified',
        };
        final pendingJson = {
          'id': 'd2',
          'host': 'example.com',
          'status': 'pending',
        };
        final failedJson = {
          'id': 'd3',
          'host': 'example.com',
          'status': 'failed',
        };

        expect(DomainConfig.fromJson(verifiedJson).status, 'verified');
        expect(DomainConfig.fromJson(pendingJson).status, 'pending');
        expect(DomainConfig.fromJson(failedJson).status, 'failed');
      });
    });

    test('should create domain with constructor', () {
      final domain = DomainConfig(
        id: 'domain-1',
        host: 'example.com',
        status: 'verified',
        isPrimary: true,
      );

      expect(domain.id, 'domain-1');
      expect(domain.host, 'example.com');
      expect(domain.status, 'verified');
      expect(domain.isPrimary, isTrue);
    });

    test('should default isPrimary in constructor', () {
      final domain = DomainConfig(
        id: 'domain-1',
        host: 'example.com',
        status: 'verified',
      );

      expect(domain.isPrimary, isFalse);
    });
  });
}
