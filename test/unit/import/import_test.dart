import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:ulink_cli/import/fdl_parser.dart';
import 'package:ulink_cli/import/fdl_mapper.dart';
import 'package:ulink_cli/import/import_parity.dart';
import 'package:ulink_cli/api/sdk_links_client.dart';
import 'package:ulink_cli/commands/import_command.dart';

import '../../helpers/test_helpers.dart';

/// Resolve an FDL fixture from the package root. `dart test` runs with the
/// working directory set to the package root, so this is stable across the
/// `Platform.script` kernel-temp indirection that trips up FixtureLoader.
String _fx(String name) => p.join(Directory.current.path, 'test', 'fixtures',
    'fdl', name);
Future<String> _loadFx(String name) => File(_fx(name)).readAsString();

void main() {
  group('FdlParser.parseExport', () {
    test('parses JSON DynamicLinkInfo batch export', () async {
      final raw = await _loadFx('fdl-export.sample.json');
      final links = FdlParser.parseExport(raw);
      expect(links.length, 3);
      expect(links[0]['link'], 'https://acme.com/promo/spring?ref=email');
      expect(links[0]['androidInfo']['androidPackageName'], 'com.acme.app');
      expect(links[0]['analyticsInfo']['itunesConnectAnalytics']['at'],
          '1010l9Qu');
    });

    test('parses newline-delimited FDL long-link URLs', () async {
      final raw = await _loadFx('fdl-links.sample.txt');
      final links = FdlParser.parseExport(raw);
      expect(links.length, 2);
      expect(links[0]['link'], 'https://acme.com/promo/spring?ref=email');
      expect(links[0]['iosInfo']['iosCustomScheme'], 'acme');
      expect(links[0]['navigationInfo']['enableForcedRedirect'], true);
      expect(links[0]['otherFallbackLink'], 'https://acme.com/promo/spring');
      expect(links[0]['analyticsInfo']['googlePlayAnalytics']['utmCampaign'],
          'spring_promo');
    });

    test('parses a CSV export with a header row (the spreadsheet case)',
        () async {
      final raw = await _loadFx('fdl-links.sample.csv');
      final links = FdlParser.parseExport(raw);
      expect(links.length, 2);
      expect(links[0]['link'], 'https://acme.com/promo/spring?ref=email');
      expect(links[0]['shortLink'], 'https://acme.page.link/promo-spring');
      expect(links[0]['androidInfo']['androidPackageName'], 'com.acme.app');
      expect(links[0]['iosInfo']['iosCustomScheme'], 'acme');
      expect(links[0]['analyticsInfo']['googlePlayAnalytics']['utmCampaign'],
          'spring_promo');
      expect(links[0]['socialMetaTagInfo']['socialTitle'], 'Spring Promo');
      // quoted cell containing a comma survives intact
      expect(links[1]['socialMetaTagInfo']['socialTitle'], "Join me, it's great");
    });

    test('CSV header maps aliases (apn/ibi/iOS Bundle ID) and parses an '
        'embedded long link', () {
      final csv = [
        'apn,iOS Bundle ID,short',
        'com.x,com.x.ios,"https://x.page.link/?link=https://x.com/deep&apn=com.x&utm_source=cfrom_url"',
      ].join('\n');
      final links = FdlParser.parseExport(csv);
      expect(links.length, 1);
      // no `link` column -> falls back to parsing the FDL long URL in `short`
      expect(links[0]['link'], 'https://x.com/deep');
      expect(links[0]['analyticsInfo']['googlePlayAnalytics']['utmSource'],
          'cfrom_url');
    });

    test('CSV with no recognized columns is rejected with a clear error', () {
      expect(() => FdlParser.parseExport('foo,bar,baz\n1,2,3'),
          throwsA(isA<FdlParseError>()));
    });

    test('accepts a bare DynamicLinkInfo object', () {
      final links = FdlParser.parseExport(jsonEncode({
        'link': 'https://x.com/a',
        'androidInfo': {'androidPackageName': 'com.x'},
      }));
      expect(links.length, 1);
      expect(links[0]['link'], 'https://x.com/a');
    });

    test('rejects a link missing the required `link` field', () {
      expect(() => FdlParser.parseExport(jsonEncode({'androidInfo': {}})),
          throwsA(isA<FdlParseError>()));
    });

    test('rejects an empty export', () {
      expect(() => FdlParser.parseExport('   '), throwsA(isA<FdlParseError>()));
      expect(() => FdlParser.parseExport('[]'), throwsA(isA<FdlParseError>()));
    });

    test('parseUrl errors clearly when `link` is absent', () {
      expect(() => FdlParser.parseUrl('https://acme.page.link/?apn=com.acme.app'),
          throwsA(isA<FdlParseError>()));
    });
  });

  group('FdlMapper', () {
    test('maps FDL to ULink losslessly (routing + attribution)', () {
      final fdl = FdlParser.parseUrl(
        'https://acme.page.link/?link=https://acme.com/x&apn=com.acme.app&afl=https://play.google.com/store/apps/details?id=com.acme.app&amv=1200&ibi=com.acme.app&isi=99&ifl=https://acme.com/ios&ius=acme&efr=1&ofl=https://acme.com/web&utm_source=s&utm_medium=m&utm_campaign=c&at=AT&ct=CT',
      );
      final link = FdlMapper.mapToUlink(fdl, domain: 'acme.ulink.app', index: 0);
      expect(link['destination'], 'https://acme.com/x');
      expect(link['routing']['android']['packageName'], 'com.acme.app');
      expect(link['routing']['android']['minVersion'], '1200');
      expect(link['routing']['ios']['appStoreId'], '99');
      expect(link['routing']['ios']['customScheme'], 'acme');
      expect(link['routing']['desktop']['fallbackUrl'], 'https://acme.com/web');
      expect(link['routing']['forceRedirect'], true);
      expect(link['attribution']['utm']['campaign'], 'c');
      expect(link['attribution']['itunes']['at'], 'AT');
    });

    test('deriveSlug reuses the original short-link path', () {
      expect(
          FdlMapper.deriveSlug(
              {'shortLink': 'https://acme.page.link/promo-spring'}, 0),
          'promo-spring');
      expect(FdlMapper.deriveSlug({}, 4), 'imported-5');
    });
  });

  group('ImportParity', () {
    test('verifyParity passes for every link in the sample export', () async {
      final raw = await _loadFx('fdl-export.sample.json');
      final links = FdlParser.parseExport(raw);
      for (var i = 0; i < links.length; i++) {
        final ulink =
            FdlMapper.mapToUlink(links[i], domain: 'demo.ulink.app', index: i);
        final r = ImportParity.verifyParity(links[i], ulink);
        expect(r.ok, isTrue,
            reason: 'link #${i + 1} parity failed: '
                '${r.failures.map((c) => c.field).toList()}');
      }
    });

    test('verifyParity detects a corrupted mapping', () {
      final fdl = FdlParser.parseUrl(
          'https://acme.page.link/?link=https://acme.com/x&utm_source=keepme');
      final ulink =
          FdlMapper.mapToUlink(fdl, domain: 'acme.ulink.app', index: 0);
      // simulate a mapping bug
      (ulink['attribution']['utm'] as Map)['source'] = 'tampered';
      final r = ImportParity.verifyParity(fdl, ulink);
      expect(r.ok, isFalse);
      expect(
          r.failures.any((c) => c.field == 'attribution.utm_source'), isTrue);
    });

    test('verifyLiveRouting passes when /sdk/resolve echoes the same '
        'per-platform routing', () {
      final fdl = FdlParser.parseUrl(
        'https://acme.page.link/?link=https://acme.com/x&apn=com.acme.app&afl=https://play.google.com/store/apps/details?id=com.acme.app&ibi=com.acme.app&isi=99&ifl=https://acme.com/ios&ofl=https://acme.com/web',
      );
      final sent = SdkLinksClient.toSdkPayload(
          FdlMapper.mapToUlink(fdl, domain: 'acme.ulink.ly', index: 0));
      final resolved = {
        'id': 'srv-generated-id',
        'slug': sent['slug'],
        'type': sent['type'],
        'fallbackUrl': sent['fallbackUrl'],
        'iosUrl': sent['iosUrl'],
        'androidUrl': sent['androidUrl'],
      };
      final r = ImportParity.verifyLiveRouting(sent, resolved);
      expect(r.ok, isTrue,
          reason: 'live parity failed: '
              '${r.failures.map((c) => c.field).toList()}');
    });

    test('verifyLiveRouting fails when the deployed link routes a platform '
        'elsewhere', () {
      final sent = {
        'type': 'unified',
        'slug': 's',
        'fallbackUrl': 'https://a',
        'iosUrl': 'https://ios',
        'androidUrl': 'https://and',
      };
      final r = ImportParity.verifyLiveRouting(
          sent, {...sent, 'iosUrl': 'https://tampered'});
      expect(r.ok, isFalse);
      expect(r.failures.any((c) => c.field == 'iosUrl'), isTrue);
    });
  });

  group('SdkLinksClient.toSdkPayload', () {
    test('serializes to the real /sdk/links schema + forwards attribution', () {
      final fdl = FdlParser.parseUrl(
        'https://acme.page.link/?link=https://acme.com/x&apn=com.acme.app&ibi=com.acme.app&isi=99&ius=acme&efr=1&ofl=https://acme.com/web&utm_source=s&utm_campaign=c&at=AT&st=Hi&si=https://acme.com/og.png',
      );
      final link = FdlMapper.mapToUlink(fdl, domain: 'acme.ulink.ly', index: 0);
      final pl = SdkLinksClient.toSdkPayload(link);
      expect(pl['type'], 'unified');
      expect(pl['fallbackUrl'], 'https://acme.com/web'); // ofl -> fallbackUrl
      expect(pl['iosUrl'], 'https://apps.apple.com/app/id99'); // from appStoreId
      expect(pl['androidUrl'],
          'https://play.google.com/store/apps/details?id=com.acme.app');
      expect(pl['allowQueryPassthrough'], true);
      expect(pl['metadata']['ogTitle'], 'Hi');
      expect(pl['metadata']['ogImage'], 'https://acme.com/og.png');
      // deep link + attribution forwarded via parameters
      expect(pl['parameters']['deepLink'], 'https://acme.com/x');
      expect(pl['parameters']['iosCustomScheme'], 'acme');
      expect(pl['parameters']['utm_source'], 's');
      expect(pl['parameters']['utm_campaign'], 'c');
      expect(pl['parameters']['at'], 'AT');
      expect(pl['parameters']['forceRedirect'], '1');
    });

    test('falls back to destination when no desktop fallback', () {
      final fdl =
          FdlParser.parseUrl('https://acme.page.link/?link=https://acme.com/only');
      final link = FdlMapper.mapToUlink(fdl, domain: 'acme.ulink.ly', index: 0);
      expect(SdkLinksClient.toSdkPayload(link)['fallbackUrl'],
          'https://acme.com/only');
    });

    // ULI-34 guard: the importer's #1 promise is "attribution preserved". Prove
    // that the full attribution set survives a /sdk/resolve round-trip when the
    // edge echoes the forwarded `parameters` back. (Live API echo is asserted in
    // QA against the deployed edge; this proves our client reads attribution back
    // intact when it is present.)
    test('attribution survives a /sdk/resolve round-trip (read-back intact)',
        () {
      final fdl = FdlParser.parseUrl(
        'https://acme.page.link/?link=https://acme.com/x&utm_source=newsletter&utm_medium=email&utm_campaign=spring&utm_term=t&utm_content=hero&gclid=G123&at=AT&ct=CT&mt=8&pt=PT',
      );
      final sent = SdkLinksClient.toSdkPayload(
          FdlMapper.mapToUlink(fdl, domain: 'acme.ulink.ly', index: 0));
      // The edge stores + echoes forwarded parameters verbatim.
      final resolved = {
        'slug': sent['slug'],
        'type': sent['type'],
        'fallbackUrl': sent['fallbackUrl'],
        'iosUrl': sent['iosUrl'],
        'androidUrl': sent['androidUrl'],
        'parameters': sent['parameters'],
      };
      final params = resolved['parameters'] as Map<String, dynamic>;
      expect(params['utm_source'], 'newsletter');
      expect(params['utm_medium'], 'email');
      expect(params['utm_campaign'], 'spring');
      expect(params['utm_term'], 't');
      expect(params['utm_content'], 'hero');
      expect(params['gclid'], 'G123');
      expect(params['at'], 'AT');
      expect(params['ct'], 'CT');
      expect(params['mt'], '8');
      expect(params['pt'], 'PT');
    });
  });

  group('ImportCommand.runFirebase (dry-run end-to-end)', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await TestHelpers.createTempDir('import_e2e_');
    });

    tearDown(() async {
      await TestHelpers.cleanupTempDir(tempDir);
    });

    test('previews every link from a fixture without hitting the network', () async {
      final inputPath =
          _fx('fdl-export.sample.json');
      final outDir = p.join(tempDir.path, 'out');

      // No SdkLinksClient network use in dry-run; a throwing client would fail
      // the test if any HTTP call were attempted.
      final command = ImportCommand(client: _ExplodingClient());
      final result = await command.runFirebase(ImportOptions(
        input: inputPath,
        domain: 'demo.ulink.app',
        out: outDir,
        live: false,
        verify: true,
      ));

      expect(result.exitCode, 0);
      expect(result.manifest['mode'], 'dry-run');
      expect(result.manifest['total'], 3);
      expect(result.manifest['created'], 0); // dry-run creates nothing
      expect(result.manifest['parityChecked'], true);
      expect(result.manifest['parityFailures'], 0);

      // Manifest + per-link artifacts written to disk.
      final manifestFile = File(p.join(outDir, 'manifest.json'));
      expect(manifestFile.existsSync(), isTrue);
      final manifest =
          jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
      final links = manifest['links'] as List;
      expect(links.length, 3);
      for (final l in links) {
        expect(l['ok'], isTrue);
        expect(l['parityOk'], isTrue);
        expect(File(p.join(outDir, 'links', '${l['slug']}.json')).existsSync(),
            isTrue);
      }
    });

    test('missing --domain returns exit code 2', () async {
      final command = ImportCommand(client: _ExplodingClient());
      final result = await command.runFirebase(ImportOptions(
        input: _fx('fdl-export.sample.json'),
        domain: null,
      ));
      expect(result.exitCode, 2);
    });
  });
}

/// A client whose network methods throw — proves dry-run never touches the net.
class _ExplodingClient extends SdkLinksClient {
  @override
  Future<CreateOutcome> liveCreate(Map<String, dynamic> link,
          {required String apiKey}) async =>
      throw StateError('network called in dry-run');
  @override
  Future<Map<String, dynamic>?> liveResolve(String shortUrl,
          {String? apiKey}) async =>
      throw StateError('network called in dry-run');
}
