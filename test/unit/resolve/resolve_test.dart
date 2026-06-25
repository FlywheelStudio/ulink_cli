import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:ulink_cli/api/sdk_links_client.dart';
import 'package:ulink_cli/commands/resolve_command.dart';

/// A fully-configured `GET /sdk/resolve` response body for a known fixture
/// link — iOS + iPad + Android + desktop routes, a deep link, a forced
/// redirect, and the full attribution set.
final Map<String, dynamic> _resolvedFixture = {
  'slug': 'promo-spring',
  'type': 'unified',
  'iosUrl': 'https://apps.apple.com/app/id99',
  'androidUrl': 'https://play.google.com/store/apps/details?id=com.acme.app',
  'fallbackUrl': 'https://acme.com/promo/spring',
  'parameters': {
    'deepLink': 'https://acme.com/promo/spring?ref=email',
    'forceRedirect': '1',
    'iosBundleId': 'com.acme.app',
    'iosCustomScheme': 'acme',
    'iosMinimumVersion': '14.0',
    'iosIpadBundleId': 'com.acme.ipad',
    'iosIpadFallbackUrl': 'https://acme.com/ipad',
    'androidPackageName': 'com.acme.app',
    'androidMinVersion': '1200',
    'utm_source': 'email',
    'utm_medium': 'newsletter',
    'utm_campaign': 'spring_promo',
    'at': '1010l9Qu',
    'ct': 'springct',
  },
};

/// Build an [SdkLinksClient] whose HTTP layer is replaced by [handler], so the
/// resolve command can be driven without touching the network.
SdkLinksClient _mockClient(
    http.Response Function(http.Request) handler) {
  return SdkLinksClient(httpClient: MockClient((req) async => handler(req)));
}

void main() {
  group('ResolveProfile.fromResolved (pure reducer)', () {
    test('reduces a full response into per-platform routes + attribution', () {
      final profile = ResolveProfile.fromResolved(_resolvedFixture);

      expect(profile.slug, 'promo-spring');
      expect(profile.type, 'unified');
      expect(profile.deepLink, 'https://acme.com/promo/spring?ref=email');
      expect(profile.forceRedirect, isTrue);

      // iOS
      expect(profile.ios.destination, 'https://apps.apple.com/app/id99');
      expect(profile.ios.app, 'com.acme.app');
      expect(profile.ios.scheme, 'acme');
      expect(profile.ios.minVersion, '14.0');

      // iPad uses its own route + bundle when set
      expect(profile.ipad.destination, 'https://acme.com/ipad');
      expect(profile.ipad.app, 'com.acme.ipad');

      // Android
      expect(profile.android.destination,
          'https://play.google.com/store/apps/details?id=com.acme.app');
      expect(profile.android.app, 'com.acme.app');
      expect(profile.android.minVersion, '1200');

      // Desktop
      expect(profile.desktop.destination, 'https://acme.com/promo/spring');

      // Attribution, in presentation order, only the present keys
      expect(profile.attribution, {
        'utm_source': 'email',
        'utm_medium': 'newsletter',
        'utm_campaign': 'spring_promo',
        'at': '1010l9Qu',
        'ct': 'springct',
      });
    });

    test('iPad falls back to the phone iOS route when no iPad route is set', () {
      final profile = ResolveProfile.fromResolved({
        'slug': 'x',
        'iosUrl': 'https://apps.apple.com/app/id1',
        'parameters': {'iosBundleId': 'com.x'},
      });
      expect(profile.ipad.destination, 'https://apps.apple.com/app/id1');
      expect(profile.ipad.app, 'com.x'); // inherits the phone bundle id
    });

    test('a link with no routes resolves to all-null platforms + no attribution',
        () {
      final profile = ResolveProfile.fromResolved({'slug': 'bare'});
      expect(profile.ios.destination, isNull);
      expect(profile.android.destination, isNull);
      expect(profile.desktop.destination, isNull);
      expect(profile.forceRedirect, isFalse);
      expect(profile.attribution, isEmpty);
    });

    test('toJson emits the flat per-platform shape the --json output spreads',
        () {
      final json = ResolveProfile.fromResolved(_resolvedFixture).toJson();
      expect(json['slug'], 'promo-spring');
      expect(json['forceRedirect'], true);
      final platforms = json['platforms'] as Map<String, dynamic>;
      expect((platforms['ios'] as Map)['destination'],
          'https://apps.apple.com/app/id99');
      expect((platforms['ipad'] as Map)['app'], 'com.acme.ipad');
      expect((platforms['android'] as Map)['minVersion'], '1200');
      expect((platforms['desktop'] as Map)['destination'],
          'https://acme.com/promo/spring');
      expect((json['attribution'] as Map)['utm_campaign'], 'spring_promo');
    });
  });

  group('ResolveCommand.run', () {
    test('resolves a known fixture URL and returns exit 0 with a profile',
        () async {
      Uri? requested;
      final cmd = ResolveCommand(client: _mockClient((req) {
        requested = req.url;
        return http.Response(jsonEncode(_resolvedFixture), 200);
      }));

      final result = await cmd.run(ResolveOptions(
        url: 'acme.ulink.app/promo-spring',
        json: true,
      ));

      expect(result.exitCode, 0);
      expect(result.profile, isNotNull);
      expect(result.profile!.android.app, 'com.acme.app');

      // It called GET /sdk/resolve with the https-normalized URL.
      expect(requested!.path, '/sdk/resolve');
      expect(requested!.queryParameters['url'],
          'https://acme.ulink.app/promo-spring');
    });

    test('forwards the API key as the x-app-key header when provided', () async {
      String? sentKey;
      final cmd = ResolveCommand(client: _mockClient((req) {
        sentKey = req.headers['x-app-key'];
        return http.Response(jsonEncode(_resolvedFixture), 200);
      }));

      await cmd.run(ResolveOptions(url: 'acme.ulink.app/x', apiKey: 'secret-key'));
      expect(sentKey, 'secret-key');
    });

    test('handles a 404 (unresolvable link) gracefully with exit 1', () async {
      final cmd = ResolveCommand(client: _mockClient((req) {
        return http.Response(
            jsonEncode({'message': 'link not found'}), 404);
      }));

      final result = await cmd.run(ResolveOptions(
        url: 'acme.ulink.app/does-not-exist',
        json: true,
      ));

      expect(result.exitCode, 1);
      expect(result.profile, isNull);
    });

    test('handles a transport error (edge unreachable) with exit 1', () async {
      final cmd = ResolveCommand(client: _mockClient((req) {
        throw Exception('connection refused');
      }));

      final result =
          await cmd.run(ResolveOptions(url: 'acme.ulink.app/x'));
      expect(result.exitCode, 1);
      expect(result.profile, isNull);
    });

    test('missing URL is a usage error (exit 2) and never hits the network',
        () async {
      var called = false;
      final cmd = ResolveCommand(client: _mockClient((req) {
        called = true;
        return http.Response('{}', 200);
      }));

      final result = await cmd.run(ResolveOptions(url: '   '));
      expect(result.exitCode, 2);
      expect(called, isFalse);
    });

    test('--help prints usage and returns exit 0 without resolving', () async {
      var called = false;
      final cmd = ResolveCommand(client: _mockClient((req) {
        called = true;
        return http.Response('{}', 200);
      }));

      final result = await cmd.run(ResolveOptions(help: true));
      expect(result.exitCode, 0);
      expect(called, isFalse);
    });
  });
}
