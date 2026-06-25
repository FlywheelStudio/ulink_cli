// `ulink verify --domain <domain>` — the activation moment. Prove a ULink
// domain is actually wired for universal/app links by fetching the public
// association files ULink hosts and (optionally) confirming a specific app is
// registered in them.
//
//   iOS     → https://<domain>/.well-known/apple-app-site-association  (AASA)
//   Android → https://<domain>/.well-known/assetlinks.json             (Digital Asset Links)
//
// This is the standalone, credential-free counterpart to the project-config
// `verify` command: it needs no ULink project, no login, and no API key — it
// issues plain read-only GETs against the public `/.well-known/` files. It is
// a faithful Dart port of the Node `@ulink/cli` `src/commands/verify.js`, and
// it shares the AASA/assetlinks parsing primitives with the project-config
// flow via `WellKnownTester` (extractAasaAppIds / extractAssetlinksApps /
// normalizeFingerprint).

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../testers/well_known_tester.dart';
import '../utils/console_style.dart';

const String _aasaPath = '/.well-known/apple-app-site-association';
const String _assetlinksPath = '/.well-known/assetlinks.json';

const String domainVerifyUsage = '''
ulink verify --domain <your.ulink.app> — check a ULink domain serves valid app-link association files

Usage
  ulink verify --domain <your.ulink.app> [options]
  ulink verify <your.ulink.app>

Options
  --domain, -d <domain>  Domain to verify (or pass it as the first argument).
  --ios <id>             Assert this iOS App ID is present, as TEAMID.bundleId
                         (e.g. ABCDE12345.com.acme.app).
  --android <id>         Assert this Android app is present, as
                         package[:SHA256FP] (e.g. com.acme.app:AB:CD:...).
  --json                 Print the machine-readable result to stdout.
  --help, -h             Show this help.

Examples
  ulink verify acme.ulink.app
  ulink verify -d acme.ulink.app --ios ABCDE12345.com.acme.app --android com.acme.app
''';

/// Options for a standalone domain `verify` run.
class DomainVerifyOptions {
  final String? domain;
  final String? ios;
  final String? android;
  final bool json;
  final bool help;

  DomainVerifyOptions({
    this.domain,
    this.ios,
    this.android,
    this.json = false,
    this.help = false,
  });
}

/// Result of running a domain verify — the process exit code plus the
/// structured result map (the same shape printed by `--json`), so callers and
/// tests can inspect the outcome without parsing stdout.
class DomainVerifyRunResult {
  final int exitCode;
  final Map<String, dynamic>? result;
  DomainVerifyRunResult(this.exitCode, this.result);
}

/// Outcome of fetching a well-known JSON file.
class _Fetched {
  final bool ok;
  final int status;
  final dynamic json;
  final String? error;
  _Fetched({required this.ok, required this.status, this.json, this.error});
}

/// Minimal logger matching the Node CLI output style and the sibling
/// `resolve` port: all progress/human output goes to stderr; stdout is
/// reserved for machine-readable output (`--json`).
class _Log {
  static void info(String m) => stderr.writeln(m);
  static void step(String m) => stderr.writeln('${ConsoleStyle.info('›')} $m');
  static void ok(String m) => stderr.writeln('${ConsoleStyle.success('✓')} $m');
  static void warn(String m) => stderr.writeln('${ConsoleStyle.warning('!')} $m');
  static void err(String m) => stderr.writeln('${ConsoleStyle.error('✗')} $m');
  static void out(String m) => stdout.writeln(m);
}

class DomainVerifyCommand {
  final http.Client client;
  final bool _ownsClient;

  DomainVerifyCommand({http.Client? client})
      : client = client ?? http.Client(),
        _ownsClient = client == null;

  /// Normalize a user-supplied domain: strip a leading scheme and any trailing
  /// path. Mirrors the Node CLI's domain cleanup in `runVerify()`.
  static String normalizeDomain(String raw) => raw
      .replaceAll(RegExp(r'^https?://'), '')
      .replaceAll(RegExp(r'/.*$'), '')
      .trim();

  /// Run `ulink verify --domain <domain>`. Returns the exit code + structured
  /// result; does not call `exit()` itself so it stays unit-testable.
  ///   0 = all checks passed, 1 = a check failed, 2 = bad usage.
  Future<DomainVerifyRunResult> run(DomainVerifyOptions opts) async {
    try {
      if (opts.help) {
        _Log.out(domainVerifyUsage);
        return DomainVerifyRunResult(0, null);
      }

      final domain = normalizeDomain(opts.domain ?? '');
      if (domain.isEmpty) {
        _Log.err(
            'Missing --domain (the ULink domain to verify). See `ulink verify --help`.');
        return DomainVerifyRunResult(2, null);
      }

      _Log.step('Verifying app-link setup for ${ConsoleStyle.bold(domain)}');
      final checks = <Map<String, dynamic>>[];

      await _checkIos(domain, opts.ios, checks);
      await _checkAndroid(domain, opts.android, checks);

      final ok = checks.every((c) => c['ok'] == true);
      final result = <String, dynamic>{'domain': domain, 'ok': ok, 'checks': checks};
      if (opts.json) {
        _Log.out(const JsonEncoder.withIndent('  ').convert(result));
      }

      _Log.info('');
      if (ok) {
        _Log.ok('${ConsoleStyle.bold(domain)} is serving valid app-link '
            'association files. Deep links can verify on-device.');
        return DomainVerifyRunResult(0, result);
      }
      _Log.err('${ConsoleStyle.bold(domain)} is not fully wired for app links '
          'yet — see the failures above.');
      return DomainVerifyRunResult(1, result);
    } finally {
      if (_ownsClient) client.close();
    }
  }

  Future<void> _checkIos(
      String domain, String? expected, List<Map<String, dynamic>> checks) async {
    final aasa = await _fetchJson('https://$domain$_aasaPath');
    if (!aasa.ok) {
      _Log.err('AASA not served (${aasa.error}) at ${ConsoleStyle.dim(_aasaPath)}');
      checks.add({'name': 'aasa', 'ok': false, 'error': aasa.error});
      return;
    }
    final ids = WellKnownTester.extractAasaAppIds(
        aasa.json is Map ? Map<String, dynamic>.from(aasa.json as Map) : null);
    _Log.ok('AASA reachable at ${ConsoleStyle.dim(_aasaPath)} — '
        '${ids.length} app ID(s) registered');
    checks.add({'name': 'aasa', 'ok': true, 'appIds': ids});

    if (expected != null) {
      final found = ids.contains(expected);
      (found ? _Log.ok : _Log.err)(
          '  iOS App ID ${ConsoleStyle.bold(expected)} '
          '${found ? 'is registered' : 'NOT found in AASA'}');
      checks.add({'name': 'ios-app', 'ok': found, 'expected': expected});
    } else if (ids.isEmpty) {
      _Log.warn('  AASA serves no app IDs yet — register your iOS App ID in '
          'the dashboard (Configuration → General → iOS).');
    }
  }

  Future<void> _checkAndroid(
      String domain, String? expected, List<Map<String, dynamic>> checks) async {
    final al = await _fetchJson('https://$domain$_assetlinksPath');
    if (!al.ok) {
      _Log.err('assetlinks.json not served (${al.error}) at '
          '${ConsoleStyle.dim(_assetlinksPath)}');
      checks.add({'name': 'assetlinks', 'ok': false, 'error': al.error});
      return;
    }
    final apps = WellKnownTester.extractAssetlinksApps(al.json);
    _Log.ok('assetlinks.json reachable at ${ConsoleStyle.dim(_assetlinksPath)} — '
        '${apps.length} app(s) registered');
    checks.add({'name': 'assetlinks', 'ok': true, 'apps': apps.map((a) => a.package).toList()});

    if (expected != null) {
      // Split "package[:SHA256FP]" on the FIRST colon — fingerprints contain
      // colons, so only the leading segment is the package name.
      final idx = expected.indexOf(':');
      final pkg = idx >= 0 ? expected.substring(0, idx) : expected;
      final fp = idx >= 0 ? expected.substring(idx + 1) : null;

      final match = apps.where((a) => a.package == pkg).firstOrNull;
      final fpOk = fp == null ||
          (match != null &&
              match.fingerprints.any((f) =>
                  WellKnownTester.normalizeFingerprint(f) ==
                  WellKnownTester.normalizeFingerprint(fp)));
      final ok = match != null && fpOk;
      (ok ? _Log.ok : _Log.err)('  Android ${ConsoleStyle.bold(pkg)} ${match == null ? 'NOT found in assetlinks.json' : fpOk ? 'is registered' : 'found, but the SHA-256 fingerprint does not match'}');
      checks.add({'name': 'android-app', 'ok': ok, 'expected': expected});
    } else if (apps.isEmpty) {
      _Log.warn('  assetlinks.json serves no apps yet — add your package + '
          'SHA-256 fingerprint(s) in the dashboard (Configuration → General → Android).');
    }
  }

  /// GET a well-known JSON file. Returns reachability + parsed body or an error.
  Future<_Fetched> _fetchJson(String url) async {
    try {
      final res = await client
          .get(Uri.parse(url), headers: {'accept': 'application/json'});
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return _Fetched(
            ok: false, status: res.statusCode, error: 'HTTP ${res.statusCode}');
      }
      try {
        return _Fetched(
            ok: true, status: res.statusCode, json: jsonDecode(res.body));
      } catch (_) {
        return _Fetched(
            ok: false,
            status: res.statusCode,
            error: 'response was not valid JSON');
      }
    } catch (e) {
      return _Fetched(ok: false, status: 0, error: e.toString());
    }
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
