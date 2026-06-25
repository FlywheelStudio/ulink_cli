// `ulink import firebase` — ingest an exported FDL config and recreate the
// links in ULink, with a built-in parity verification step.
//
// Faithful Dart port of the Node `@ulink/cli` `src/commands/import-firebase.js`.

import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

import '../api/sdk_links_client.dart';
import '../import/fdl_mapper.dart';
import '../import/fdl_parser.dart';
import '../import/import_parity.dart';
import '../utils/console_style.dart';

const String importFirebaseUsage = '''
ulink import firebase — migrate Firebase Dynamic Links to ULink

Usage
  ulink import firebase --input <export> --domain <your.ulink.app> [options]

Required
  --input, -i <path>     Path to your FDL export (JSON DynamicLinkInfo, a batch
                         { "links": [...] }, a newline-delimited list of
                         *.page.link URLs, or a CSV with a header row of your
                         link inventory). Use "-" to read from stdin.
  --domain, -d <domain>  Your ULink domain that the new links live under.

Options
  --out, -o <dir>        Write per-link JSON + a manifest here (default ./ulink-import).
  --dry-run              Preview only; never calls the ULink API (default ON
                         until --live is passed).
  --live                 Create links via the ULink API (needs --api-key/ULINK_API_KEY).
  --api-key <key>        ULink API key for --live (or set ULINK_API_KEY).
  --verify               Run routing+attribution parity checks (default ON).
  --no-verify            Skip parity checks.
  --json                 Print the manifest as JSON to stdout (for piping).
  --help, -h             Show this help.

Examples
  ulink import firebase -i fdl-export.json -d acme.ulink.app
  cat links.txt | ulink import firebase -i - -d acme.ulink.app --json
  ulink import firebase -i fdl-export.json -d acme.ulink.app --live --api-key \$ULINK_API_KEY
''';

/// Options for an `import firebase` run.
class ImportOptions {
  final String? input;
  final String? domain;
  final String? out;
  final bool live;
  final bool verify;
  final bool json;
  final bool help;
  final String? apiKey;

  ImportOptions({
    this.input,
    this.domain,
    this.out,
    this.live = false,
    this.verify = true,
    this.json = false,
    this.help = false,
    this.apiKey,
  });
}

/// Result of running `import firebase` — the process exit code plus the
/// generated manifest (so callers/tests can inspect the outcome).
class ImportRunResult {
  final int exitCode;
  final Map<String, dynamic> manifest;
  ImportRunResult(this.exitCode, this.manifest);
}

/// Minimal logger matching the Node CLI output style. All progress goes to
/// stderr; stdout is reserved for machine-readable output (`--json`).
class _Log {
  static void info(String m) => stderr.writeln(m);
  static void step(String m) =>
      stderr.writeln('${ConsoleStyle.info('›')} $m');
  static void ok(String m) =>
      stderr.writeln('${ConsoleStyle.success('✓')} $m');
  static void warn(String m) =>
      stderr.writeln('${ConsoleStyle.warning('!')} $m');
  static void err(String m) =>
      stderr.writeln('${ConsoleStyle.error('✗')} $m');
  static void out(String m) => stdout.writeln(m);
}

class ImportCommand {
  final SdkLinksClient client;
  ImportCommand({SdkLinksClient? client})
      : client = client ?? SdkLinksClient();

  static Future<String> _readInput(String inputPath) async {
    if (inputPath == '-') {
      return await utf8.decodeStream(stdin);
    }
    return File(inputPath).readAsString();
  }

  /// Run `ulink import firebase`. Returns the exit code + manifest; does not
  /// call `exit()` itself so it stays unit-testable.
  Future<ImportRunResult> runFirebase(ImportOptions opts) async {
    if (opts.help) {
      _Log.out(_styledUsage());
      return ImportRunResult(0, {});
    }
    if (opts.input == null) {
      _Log.err('Missing --input. See `ulink import firebase --help`.');
      return ImportRunResult(2, {});
    }
    if (opts.domain == null) {
      _Log.err(
          'Missing --domain (your ULink domain). See `ulink import firebase --help`.');
      return ImportRunResult(2, {});
    }

    final live = opts.live;
    final verify = opts.verify;
    final outDir = opts.out ?? 'ulink-import';
    final apiKey = opts.apiKey ?? Platform.environment['ULINK_API_KEY'];

    // 1. Read + parse the export.
    String raw;
    try {
      raw = await _readInput(opts.input!);
    } catch (e) {
      _Log.err('Could not read input "${opts.input}": $e');
      return ImportRunResult(1, {});
    }

    List<Map<String, dynamic>> links;
    try {
      links = FdlParser.parseExport(raw);
    } on FdlParseError catch (e) {
      _Log.err('Could not parse FDL export: ${e.message}');
      return ImportRunResult(1, {});
    }
    _Log.step(
        'Parsed ${ConsoleStyle.bold('${links.length}')} Firebase Dynamic Link${links.length == 1 ? '' : 's'} from ${opts.input}');

    if (live && (apiKey == null || apiKey.isEmpty)) {
      _Log.err('--live requires --api-key or the ULINK_API_KEY env var.');
      return ImportRunResult(2, {});
    }
    if (!live) {
      _Log.info(ConsoleStyle.dim(
          '  (dry-run: no links will be created; pass --live to write to ULink)'));
    }

    // 2. Map -> 3. create/preview -> 4. verify, per link.
    final results = <Map<String, dynamic>>[];
    var created = 0;
    var parityFailures = 0;
    final slugSeen = <String, int>{};

    for (var i = 0; i < links.length; i++) {
      final fdl = links[i];
      Map<String, dynamic> ulink;
      try {
        ulink = FdlMapper.mapToUlink(fdl, domain: opts.domain!, index: i);
      } catch (e) {
        _Log.err('Link #${i + 1}: mapping failed: $e');
        results.add({'index': i, 'ok': false, 'error': '$e', 'source': fdl});
        parityFailures++;
        continue;
      }

      // Guard against duplicate slugs colliding silently.
      final slug = ulink['slug'] as String;
      final prev = slugSeen[slug];
      if (prev != null) {
        ulink['slug'] = '$slug-${i + 1}';
        _Log.warn(
            'Link #${i + 1}: slug collided with #${prev + 1}; using "${ulink['slug']}" instead.');
      }
      slugSeen[ulink['slug'] as String] = i;

      CreateOutcome outcome;
      try {
        outcome = live
            ? await client.liveCreate(ulink, apiKey: apiKey!)
            : SdkLinksClient.previewCreate(ulink);
        if (outcome.status == 'created') created++;
      } catch (e) {
        _Log.err('Link #${i + 1}: create failed: $e');
        results.add({'index': i, 'ok': false, 'error': '$e', 'link': ulink});
        parityFailures++;
        continue;
      }

      final short = outcome.shortLink;

      // Static parity: the mapping preserves routing + attribution intent.
      ParityResult? parity;
      if (verify) parity = ImportParity.verifyParity(fdl, ulink);

      // Live redirect parity: ask the deployed edge where the created link
      // actually routes. Only meaningful for links created live; degrades to a
      // warning (not a failure) when /sdk/resolve is unreachable.
      LiveParityResult? liveParity;
      var liveProbed = false;
      if (verify && live && outcome.status == 'created') {
        liveProbed = true;
        final resolved = await client.liveResolve(short, apiKey: apiKey);
        if (resolved != null) {
          liveParity = ImportParity.verifyLiveRouting(outcome.payload, resolved);
        }
      }

      final staticOk = !verify || parity!.ok;
      final liveOk = liveParity == null || liveParity.ok;
      final linkOk = staticOk && liveOk;
      if (verify && !linkOk) parityFailures++;

      final tag = !verify
          ? ''
          : linkOk
              ? ' ${ConsoleStyle.success('parity OK')}'
              : ' ${ConsoleStyle.error('PARITY FAIL')}';
      final fromTo = fdl['shortLink'] != null
          ? '${ConsoleStyle.dim('${fdl['shortLink']}')} → '
          : '';
      _Log.ok('#${i + 1} $fromTo${ConsoleStyle.bold(short)}$tag');
      if (verify && parity != null && !parity.ok) {
        for (final ch in parity.failures) {
          _Log.warn(
              '    ${ch.field}: FDL=${jsonEncode(ch.fdl)} ULink=${jsonEncode(ch.ulink)}');
        }
      }
      if (liveParity != null && !liveParity.ok) {
        for (final ch in liveParity.failures) {
          _Log.warn(
              '    live ${ch.field}: sent=${jsonEncode(ch.sent)} resolved=${jsonEncode(ch.resolved)}');
        }
      }
      if (liveProbed && liveParity == null) {
        _Log.warn(
            '    live redirect parity skipped: GET /sdk/resolve unreachable for $short');
      }

      results.add({
        'index': i,
        'ok': linkOk,
        'shortLink': short,
        'status': outcome.status,
        'link': ulink,
        'parityOk': parity?.ok,
        'liveParityOk': liveParity?.ok,
      });
    }

    // 5. Write artifacts.
    final manifest = <String, dynamic>{
      'tool': 'ulink import firebase',
      'generatedFrom': opts.input,
      'domain': opts.domain,
      'mode': live ? 'live' : 'dry-run',
      'total': links.length,
      'created': created,
      'parityChecked': verify,
      'parityFailures': parityFailures,
      'links': results.map((r) {
        final link = r['link'] as Map<String, dynamic>?;
        return {
          'index': r['index'],
          'ok': r['ok'],
          'shortLink': r['shortLink'],
          'status': r['status'],
          'error': r['error'],
          'slug': link?['slug'],
          'destination': link?['destination'],
          'parityOk': r['parityOk'],
          'liveParityOk': r['liveParityOk'],
        };
      }).toList(),
    };

    try {
      await Directory(outDir).create(recursive: true);
      await File(p.join(outDir, 'manifest.json'))
          .writeAsString(_pretty(manifest));
      await Directory(p.join(outDir, 'links')).create(recursive: true);
      var linkCount = 0;
      for (final r in results) {
        final link = r['link'] as Map<String, dynamic>?;
        if (link == null) continue;
        await File(p.join(outDir, 'links', '${link['slug']}.json'))
            .writeAsString(_pretty(link));
        linkCount++;
      }
      _Log.step(
          'Wrote manifest + $linkCount link definitions to ${ConsoleStyle.bold(outDir)}/');
    } catch (e) {
      _Log.warn('Could not write artifacts to $outDir: $e');
    }

    if (opts.json) _Log.out(_pretty(manifest));

    // 6. Summary + exit code.
    final okCount = results.where((r) => r['ok'] == true).length;
    _Log.info('');
    if (parityFailures == 0) {
      _Log.ok(
          '$okCount/${links.length} links ${live ? 'created' : 'previewed'} with ${verify ? 'verified routing + attribution parity' : 'parity check skipped'}.');
      if (!live) {
        _Log.info(ConsoleStyle.dim(
            '  Re-run with --live --api-key <key> to create them in ULink.'));
      }
      return ImportRunResult(0, manifest);
    }
    _Log.err(
        '$parityFailures link(s) failed (mapping, create, or parity). See output above and $outDir/manifest.json.');
    return ImportRunResult(1, manifest);
  }

  static String _pretty(Object o) =>
      const JsonEncoder.withIndent('  ').convert(o);

  static String _styledUsage() {
    // Apply bold styling to the section markers in the usage string.
    return importFirebaseUsage
        .replaceAll('ulink import firebase —',
            '${ConsoleStyle.bold('ulink import firebase')} —')
        .replaceAllMapped(
          RegExp(r'^(Usage|Required|Options|Examples)$', multiLine: true),
          (m) => ConsoleStyle.bold(m[1]!),
        );
  }
}

