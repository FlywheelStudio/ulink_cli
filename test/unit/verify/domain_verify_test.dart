import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:ulink_cli/commands/domain_verify_command.dart';
import 'package:ulink_cli/testers/well_known_tester.dart';

/// A well-formed AASA file declaring one iOS App ID, plus a legacy `apps[]`
/// entry, to exercise both extraction paths.
final Map<String, dynamic> _aasaFixture = {
  'applinks': {
    'apps': <String>['LEGACY123.com.acme.legacy'],
    'details': [
      {
        'appID': 'ABCDE12345.com.acme.app',
        'paths': ['*'],
      },
      {
        'appIDs': ['FGHIJ67890.com.acme.other'],
        'components': [],
      },
    ],
  },
};

/// A well-formed assetlinks.json declaring one Android app with a fingerprint.
final List<dynamic> _assetlinksFixture = [
  {
    'relation': ['delegate_permission/common.handle_all_urls'],
    'target': {
      'namespace': 'android_app',
      'package_name': 'com.acme.app',
      'sha256_cert_fingerprints': ['AB:CD:EF:01:23:45:67:89'],
    },
  },
];

/// Build a [DomainVerifyCommand] whose HTTP layer is replaced by [handler], so
/// the command can be driven without touching the network.
DomainVerifyCommand _cmd(http.Response Function(http.Request) handler) =>
    DomainVerifyCommand(client: MockClient((req) async => handler(req)));

http.Response _json(Object body) =>
    http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});

/// Route a request to the AASA or assetlinks fixture based on its path.
http.Response Function(http.Request) _bothServed({
  Object? aasa,
  Object? assetlinks,
}) =>
    (req) {
      if (req.url.path.endsWith('apple-app-site-association')) {
        return aasa == null ? http.Response('not found', 404) : _json(aasa);
      }
      if (req.url.path.endsWith('assetlinks.json')) {
        return assetlinks == null ? http.Response('not found', 404) : _json(assetlinks);
      }
      return http.Response('unexpected', 500);
    };

void main() {
  group('WellKnownTester.extractAasaAppIds', () {
    test('collects appID, appIDs[] and legacy apps[]', () {
      final ids = WellKnownTester.extractAasaAppIds(_aasaFixture);
      expect(ids, containsAll(<String>[
        'ABCDE12345.com.acme.app',
        'FGHIJ67890.com.acme.other',
        'LEGACY123.com.acme.legacy',
      ]));
    });

    test('returns empty for a missing/!map applinks', () {
      expect(WellKnownTester.extractAasaAppIds(null), isEmpty);
      expect(WellKnownTester.extractAasaAppIds({'applinks': 'nope'}), isEmpty);
    });
  });

  group('WellKnownTester.extractAssetlinksApps', () {
    test('collects android_app package + fingerprints', () {
      final apps = WellKnownTester.extractAssetlinksApps(_assetlinksFixture);
      expect(apps, hasLength(1));
      expect(apps.first.package, 'com.acme.app');
      expect(apps.first.fingerprints, ['AB:CD:EF:01:23:45:67:89']);
    });

    test('ignores non-android_app statements and non-list input', () {
      expect(WellKnownTester.extractAssetlinksApps('nope'), isEmpty);
      expect(
        WellKnownTester.extractAssetlinksApps([
          {'target': {'namespace': 'web', 'site': 'https://acme.com'}},
        ]),
        isEmpty,
      );
    });
  });

  group('WellKnownTester.normalizeFingerprint', () {
    test('strips colons and lowercases', () {
      expect(WellKnownTester.normalizeFingerprint('AB:CD:ef'), 'abcdef');
    });
  });

  group('DomainVerifyCommand.normalizeDomain', () {
    test('strips scheme and path', () {
      expect(DomainVerifyCommand.normalizeDomain('https://acme.ulink.app/foo'),
          'acme.ulink.app');
      expect(DomainVerifyCommand.normalizeDomain('http://acme.ulink.app'),
          'acme.ulink.app');
      expect(DomainVerifyCommand.normalizeDomain('acme.ulink.app'),
          'acme.ulink.app');
    });
  });

  group('DomainVerifyCommand.run — usage', () {
    test('help → exit 0', () async {
      final r = await _cmd((_) => http.Response('', 200))
          .run(DomainVerifyOptions(help: true));
      expect(r.exitCode, 0);
    });

    test('missing domain → exit 2', () async {
      final r = await _cmd((_) => http.Response('', 200))
          .run(DomainVerifyOptions(domain: '   '));
      expect(r.exitCode, 2);
    });
  });

  group('DomainVerifyCommand.run — reachability', () {
    test('both files served and valid → exit 0', () async {
      final r = await _cmd(_bothServed(
        aasa: _aasaFixture,
        assetlinks: _assetlinksFixture,
      )).run(DomainVerifyOptions(domain: 'acme.ulink.app'));
      expect(r.exitCode, 0);
      expect(r.result!['ok'], isTrue);
    });

    test('AASA missing → exit 1 with aasa check failed', () async {
      final r = await _cmd(_bothServed(
        aasa: null,
        assetlinks: _assetlinksFixture,
      )).run(DomainVerifyOptions(domain: 'acme.ulink.app'));
      expect(r.exitCode, 1);
      final checks = r.result!['checks'] as List;
      expect(checks.any((c) => c['name'] == 'aasa' && c['ok'] == false), isTrue);
    });

    test('non-JSON body → check fails', () async {
      final r = await _cmd((req) {
        if (req.url.path.endsWith('apple-app-site-association')) {
          return http.Response('<html>not json</html>', 200);
        }
        return _json(_assetlinksFixture);
      }).run(DomainVerifyOptions(domain: 'acme.ulink.app'));
      expect(r.exitCode, 1);
    });
  });

  group('DomainVerifyCommand.run — explicit assertions', () {
    test('--ios present → passes', () async {
      final r = await _cmd(_bothServed(
        aasa: _aasaFixture,
        assetlinks: _assetlinksFixture,
      )).run(DomainVerifyOptions(
        domain: 'acme.ulink.app',
        ios: 'ABCDE12345.com.acme.app',
      ));
      expect(r.exitCode, 0);
      final checks = r.result!['checks'] as List;
      expect(checks.any((c) => c['name'] == 'ios-app' && c['ok'] == true), isTrue);
    });

    test('--ios absent from AASA → fails (exit 1)', () async {
      final r = await _cmd(_bothServed(
        aasa: _aasaFixture,
        assetlinks: _assetlinksFixture,
      )).run(DomainVerifyOptions(
        domain: 'acme.ulink.app',
        ios: 'ZZZZZ00000.com.notme.app',
      ));
      expect(r.exitCode, 1);
    });

    test('--android package only (no fingerprint) → presence pass', () async {
      final r = await _cmd(_bothServed(
        aasa: _aasaFixture,
        assetlinks: _assetlinksFixture,
      )).run(DomainVerifyOptions(
        domain: 'acme.ulink.app',
        android: 'com.acme.app',
      ));
      expect(r.exitCode, 0);
    });

    test('--android with matching fingerprint (colon/case-insensitive) → pass',
        () async {
      final r = await _cmd(_bothServed(
        aasa: _aasaFixture,
        assetlinks: _assetlinksFixture,
      )).run(DomainVerifyOptions(
        domain: 'acme.ulink.app',
        android: 'com.acme.app:abcdef0123456789',
      ));
      expect(r.exitCode, 0);
      final checks = r.result!['checks'] as List;
      expect(
          checks.any((c) => c['name'] == 'android-app' && c['ok'] == true), isTrue);
    });

    test('--android with wrong fingerprint → fail (exit 1)', () async {
      final r = await _cmd(_bothServed(
        aasa: _aasaFixture,
        assetlinks: _assetlinksFixture,
      )).run(DomainVerifyOptions(
        domain: 'acme.ulink.app',
        android: 'com.acme.app:DEADBEEF',
      ));
      expect(r.exitCode, 1);
    });

    test('--android package not present → fail (exit 1)', () async {
      final r = await _cmd(_bothServed(
        aasa: _aasaFixture,
        assetlinks: _assetlinksFixture,
      )).run(DomainVerifyOptions(
        domain: 'acme.ulink.app',
        android: 'com.notme.app',
      ));
      expect(r.exitCode, 1);
    });
  });

  group('DomainVerifyCommand.run — json result shape', () {
    test('result map carries domain, ok and per-file checks', () async {
      final r = await _cmd(_bothServed(
        aasa: _aasaFixture,
        assetlinks: _assetlinksFixture,
      )).run(DomainVerifyOptions(domain: 'https://acme.ulink.app/x', json: true));
      expect(r.result!['domain'], 'acme.ulink.app');
      expect(r.result!['ok'], isTrue);
      final names =
          (r.result!['checks'] as List).map((c) => c['name']).toList();
      expect(names, containsAll(<String>['aasa', 'assetlinks']));
    });
  });
}
