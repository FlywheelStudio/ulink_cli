// `ulink resolve <url>` — given a ULink short URL, report where each platform
// (iOS / iPad / Android / desktop) actually resolves and which attribution
// params the link forwards, by asking the live edge: GET /sdk/resolve.
//
// This lifts the live redirect-parity that runs *inside* the importer
// (`--live --verify`) into a standalone verification command. It is read-only:
// it never creates, mutates, or deletes anything — just reads back how a link
// the edge already serves will route. An API key is optional; pass one
// (--api-key / ULINK_API_KEY) when the link's forwarded parameters are only
// visible to its owning app.
//
// Faithful Dart port of the Node `@ulink/cli` `src/commands/resolve.js`.

import 'dart:convert';
import 'dart:io';

import '../api/sdk_links_client.dart';
import '../utils/console_style.dart';

const String resolveUsage = '''
ulink resolve — show where a ULink short URL resolves per platform

Usage
  ulink resolve <https://your.ulink.app/slug> [options]
  ulink resolve --url <shortUrl>

Options
  --url <shortUrl>       The ULink short URL (or pass it as the first argument).
  --api-key <key>        ULink API key (or set ULINK_API_KEY). Optional; needed
                         only to read a link's forwarded attribution parameters.
  --json                 Print the machine-readable resolution to stdout.
  --help, -h             Show this help.

Examples
  ulink resolve https://acme.ulink.app/promo-spring
  ulink resolve acme.ulink.app/promo-spring --json
''';

/// Attribution parameter names forwarded on the created link (mirrors the keys
/// `SdkLinksClient.toSdkPayload()` writes into `parameters`). Order is the
/// presentation order used in the human-readable output.
const List<String> attributionParamKeys = [
  'utm_source',
  'utm_medium',
  'utm_campaign',
  'utm_term',
  'utm_content',
  'gclid',
  'at',
  'ct',
  'mt',
  'pt',
];

/// Options for a `resolve` run.
class ResolveOptions {
  final String? url;
  final String? apiKey;
  final bool json;
  final bool help;

  ResolveOptions({this.url, this.apiKey, this.json = false, this.help = false});
}

/// Result of running `resolve` — the process exit code plus the resolved
/// profile (or null on failure), so callers/tests can inspect the outcome.
class ResolveRunResult {
  final int exitCode;
  final ResolveProfile? profile;
  ResolveRunResult(this.exitCode, this.profile);
}

/// Per-platform resolution of a single platform (iOS / iPad / Android /
/// desktop). `destination` is where the link routes that platform; the
/// remaining fields are present only when configured.
class PlatformResolution {
  final String? destination;
  final String? app;
  final String? scheme;
  final String? minVersion;

  PlatformResolution({this.destination, this.app, this.scheme, this.minVersion});

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{'destination': destination};
    if (app != null) m['app'] = app;
    if (scheme != null) m['scheme'] = scheme;
    if (minVersion != null) m['minVersion'] = minVersion;
    return m;
  }
}

/// Normalized per-platform view of a `GET /sdk/resolve` response. Built by the
/// pure [ResolveProfile.fromResolved] reducer so it is directly unit-testable.
class ResolveProfile {
  final String? slug;
  final String? type;
  final String? deepLink;
  final bool forceRedirect;
  final PlatformResolution ios;
  final PlatformResolution ipad;
  final PlatformResolution android;
  final PlatformResolution desktop;
  final Map<String, String> attribution;

  ResolveProfile({
    this.slug,
    this.type,
    this.deepLink,
    this.forceRedirect = false,
    required this.ios,
    required this.ipad,
    required this.android,
    required this.desktop,
    required this.attribution,
  });

  /// Normalize a raw `GET /sdk/resolve` response body into a per-platform view.
  /// Pure (no I/O) so it is directly unit-testable. Mirrors `resolveProfile()`
  /// in the Node `src/commands/resolve.js`.
  static ResolveProfile fromResolved(Map<String, dynamic>? resolved) {
    final p = _m(resolved?['parameters']);
    final iosUrl = _norm(resolved?['iosUrl']);
    final androidUrl = _norm(resolved?['androidUrl']);
    final desktopUrl = _norm(resolved?['fallbackUrl']);

    final attribution = <String, String>{};
    for (final k in attributionParamKeys) {
      final v = _norm(p[k]);
      if (v != null) attribution[k] = v;
    }

    return ResolveProfile(
      slug: _norm(resolved?['slug']),
      type: _norm(resolved?['type']),
      deepLink: _norm(p['deepLink']),
      forceRedirect: _norm(p['forceRedirect']) == '1',
      ios: PlatformResolution(
        destination: iosUrl,
        app: _norm(p['iosBundleId']),
        scheme: _norm(p['iosCustomScheme']),
        minVersion: _norm(p['iosMinimumVersion']),
      ),
      ipad: PlatformResolution(
        // iPad falls back to the phone iOS route unless an iPad-specific one was set.
        destination: _norm(p['iosIpadFallbackUrl']) ?? iosUrl,
        app: _norm(p['iosIpadBundleId']) ?? _norm(p['iosBundleId']),
      ),
      android: PlatformResolution(
        destination: androidUrl,
        app: _norm(p['androidPackageName']),
        minVersion: _norm(p['androidMinVersion']),
      ),
      desktop: PlatformResolution(destination: desktopUrl),
      attribution: attribution,
    );
  }

  /// Flat JSON shape matching the Node CLI's `--json` profile fields exactly.
  Map<String, dynamic> toJson() => {
        'slug': slug,
        'type': type,
        'deepLink': deepLink,
        'forceRedirect': forceRedirect,
        'platforms': {
          'ios': ios.toJson(),
          'ipad': {'destination': ipad.destination, if (ipad.app != null) 'app': ipad.app},
          'android': {
            'destination': android.destination,
            if (android.app != null) 'app': android.app,
            if (android.minVersion != null) 'minVersion': android.minVersion,
          },
          'desktop': {'destination': desktop.destination},
        },
        'attribution': attribution,
      };
}

String? _norm(dynamic v) =>
    (v == null || v == '') ? null : v.toString();

Map<String, dynamic> _m(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

/// Minimal logger matching the Node CLI output style. All progress/human output
/// goes to stderr; stdout is reserved for machine-readable output (`--json`).
class _Log {
  static void info(String m) => stderr.writeln(m);
  static void step(String m) => stderr.writeln('${ConsoleStyle.info('›')} $m');
  static void ok(String m) => stderr.writeln('${ConsoleStyle.success('✓')} $m');
  static void err(String m) => stderr.writeln('${ConsoleStyle.error('✗')} $m');
  static void out(String m) => stdout.writeln(m);
}

const Map<String, String> _platformLabels = {
  'ios': 'iOS',
  'ipad': 'iPad',
  'android': 'Android',
  'desktop': 'Desktop',
};

class ResolveCommand {
  final SdkLinksClient client;
  ResolveCommand({SdkLinksClient? client}) : client = client ?? SdkLinksClient();

  /// Run `ulink resolve <url>`. Returns the exit code + profile; does not call
  /// `exit()` itself so it stays unit-testable.
  ///   0 = resolved, 1 = not found / unreachable / API error, 2 = bad usage.
  Future<ResolveRunResult> run(ResolveOptions opts) async {
    if (opts.help) {
      _Log.out(resolveUsage);
      return ResolveRunResult(0, null);
    }

    final shortUrl = (opts.url ?? '').trim();
    if (shortUrl.isEmpty) {
      _Log.err('Missing the ULink short URL. Usage: `ulink resolve <url>` (see --help).');
      return ResolveRunResult(2, null);
    }

    final apiKey = opts.apiKey ?? Platform.environment['ULINK_API_KEY'];
    _Log.step('Resolving ${ConsoleStyle.bold(shortUrl)} via the live ULink edge');

    final r = await client.resolve(shortUrl, apiKey: apiKey);

    if (!r.ok) {
      if (r.status == 404) {
        _Log.err('Not found (404): no ULink domain or link matched ${ConsoleStyle.bold(shortUrl)}.');
        _Log.info(ConsoleStyle.dim('    Check the domain is a live ULink domain and the slug exists.'));
      } else if (r.status == 0) {
        _Log.err('Could not reach the ULink edge: ${r.error}');
      } else {
        _Log.err('Resolve failed (HTTP ${r.status}): ${r.error}');
      }
      if (opts.json) {
        _Log.out(const JsonEncoder.withIndent('  ').convert({
          'url': shortUrl,
          'ok': false,
          'status': r.status,
          'error': r.error,
        }));
      }
      return ResolveRunResult(1, null);
    }

    final profile = ResolveProfile.fromResolved(r.body);
    if (opts.json) {
      _Log.out(const JsonEncoder.withIndent('  ').convert({
        'url': shortUrl,
        'ok': true,
        'status': r.status,
        ...profile.toJson(),
      }));
    } else {
      _printHuman(shortUrl, profile);
    }
    return ResolveRunResult(0, profile);
  }

  void _printHuman(String shortUrl, ResolveProfile profile) {
    final slugTail = profile.slug != null
        ? ConsoleStyle.dim('  (slug: ${profile.slug}${profile.type != null ? ', type: ${profile.type}' : ''})')
        : '';
    _Log.ok('Resolved ${ConsoleStyle.bold(shortUrl)}$slugTail');
    if (profile.deepLink != null) {
      _Log.info('  ${ConsoleStyle.dim('in-app deep link →')} ${profile.deepLink}');
    }
    if (profile.forceRedirect) {
      _Log.info('  ${ConsoleStyle.dim('forced redirect:')} on');
    }

    _Log.info('');
    _Log.info(ConsoleStyle.bold('  Per-platform resolution'));
    final platforms = <String, PlatformResolution>{
      'ios': profile.ios,
      'ipad': profile.ipad,
      'android': profile.android,
      'desktop': profile.desktop,
    };
    for (final key in ['ios', 'ipad', 'android', 'desktop']) {
      final pl = platforms[key]!;
      final dest = pl.destination ?? ConsoleStyle.dim('(none — no route configured)');
      final extra = <String>[];
      if (pl.app != null) extra.add('app ${pl.app}');
      if (pl.scheme != null) extra.add('scheme ${pl.scheme}://');
      if (pl.minVersion != null) extra.add('min v${pl.minVersion}');
      final tail = extra.isNotEmpty ? ConsoleStyle.dim('  [${extra.join(', ')}]') : '';
      _Log.info('    ${_platformLabels[key]!.padRight(8)} $dest$tail');
    }

    _Log.info('');
    final attrKeys = profile.attribution.keys.toList();
    if (attrKeys.isNotEmpty) {
      _Log.info(ConsoleStyle.bold('  Attribution forwarded (${attrKeys.length})'));
      for (final k in attrKeys) {
        _Log.info('    ${k.padRight(14)} ${profile.attribution[k]}');
      }
    } else {
      _Log.info(ConsoleStyle.dim('  No attribution parameters forwarded on this link.'));
      _Log.info(ConsoleStyle.dim('    (Pass --api-key / ULINK_API_KEY if these are only visible to the owning app.)'));
    }
  }
}
