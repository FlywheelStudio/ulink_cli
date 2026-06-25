// ULink backend client for the link-creation/resolution API used by the
// Firebase Dynamic Links importer.
//
// Verified contract (docs.ulink.ly/rest-api):
//   Base URL:  https://api.ulink.ly
//   Auth:      header `x-app-key: <api-key>`
//   Create:    POST /sdk/links
//   Resolve:   GET  /sdk/resolve?url=<shortUrl>
//
// Create request body (the real ULink link schema):
//   { type, slug, fallbackUrl, iosUrl, androidUrl, parameters, metadata,
//     allowQueryPassthrough }
//   metadata: { ogTitle, ogDescription, ogImage }
// Create response: { id, slug, shortUrl, type, fallbackUrl, createdAt }
//
// Two modes:
//   - dry-run (default): no network. Returns a deterministic preview of the
//     would-create payload + short URL. Safe against any export.
//   - live: POSTs to /sdk/links. Requires an API key (--api-key / ULINK_API_KEY).
//
// Faithful Dart port of the Node `@ulink/cli` `src/backend/client.js`.

import 'dart:convert';
import 'package:http/http.dart' as http;

const String _defaultApiBase = 'https://api.ulink.ly';

/// Outcome of a create (live or preview).
class CreateOutcome {
  final String status; // 'preview' | 'created'
  final String shortLink;
  final Map<String, dynamic> payload;

  /// For preview: the internal ULink link map. For live: the API response body.
  final Map<String, dynamic> link;
  CreateOutcome({
    required this.status,
    required this.shortLink,
    required this.payload,
    required this.link,
  });
}

/// Explicit resolve outcome so callers can distinguish a genuine 404 (link not
/// found) from a transport error.
class ResolveOutcome {
  final bool ok;
  final int status;
  final Map<String, dynamic>? body;
  final String? error;
  ResolveOutcome({required this.ok, required this.status, this.body, this.error});
}

String _shortUrlFor(Map<String, dynamic> link) =>
    'https://${link['domain']}/${link['slug']}';

String _playStoreUrl(String pkg) =>
    'https://play.google.com/store/apps/details?id=$pkg';
String _appStoreUrl(String id) => 'https://apps.apple.com/app/id$id';

Map<String, dynamic> _m(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

Map<String, dynamic> _pruneEmpty(Map<String, dynamic> obj) {
  final out = <String, dynamic>{};
  obj.forEach((k, v) {
    if (v == null || v == '') return;
    out[k] = v;
  });
  return out;
}

class SdkLinksClient {
  final String apiBase;
  final http.Client _http;

  SdkLinksClient({String? apiBase, http.Client? httpClient})
      : apiBase = apiBase ?? _defaultApiBase,
        _http = httpClient ?? http.Client();

  static String shortUrlFor(Map<String, dynamic> link) => _shortUrlFor(link);

  /// Serialize our rich internal ULink link definition (see fdl_mapper.dart)
  /// into the real `POST /sdk/links` request body. Anything the ULink schema has
  /// no first-class field for (the in-app deep link, custom scheme, app ids, min
  /// versions, and all attribution params) rides along in `parameters` with
  /// `allowQueryPassthrough` so it is forwarded to the app on open — preserving
  /// routing intent and attribution end to end.
  static Map<String, dynamic> toSdkPayload(Map<String, dynamic> link) {
    final r = _m(link['routing']);
    final ios = _m(r['ios']);
    final android = _m(r['android']);
    final ipad = _m(ios['ipad']);
    final at = _m(link['attribution']);
    final utm = _m(at['utm']);
    final it = _m(at['itunes']);
    final social = _m(link['social']);
    final desktop = _m(r['desktop']);

    final iosUrl = ios['fallbackUrl'] ??
        (ios['appStoreId'] != null ? _appStoreUrl('${ios['appStoreId']}') : null);
    final androidUrl = android['fallbackUrl'] ??
        (android['packageName'] != null
            ? _playStoreUrl('${android['packageName']}')
            : null);
    final fallbackUrl = desktop['fallbackUrl'] ?? link['destination'];

    // Forwarded parameters: the deep link + everything not expressible up top.
    final parameters = _pruneEmpty({
      'deepLink': link['destination'],
      'iosBundleId': ios['bundleId'],
      'iosCustomScheme': ios['customScheme'],
      'iosMinimumVersion': ios['minVersion'],
      'iosIpadBundleId': ipad['bundleId'],
      'iosIpadFallbackUrl': ipad['fallbackUrl'],
      'androidPackageName': android['packageName'],
      'androidMinVersion': android['minVersion'],
      'forceRedirect': r['forceRedirect'] == true ? '1' : null,
      'utm_source': utm['source'],
      'utm_medium': utm['medium'],
      'utm_campaign': utm['campaign'],
      'utm_term': utm['term'],
      'utm_content': utm['content'],
      'gclid': at['gclid'],
      'at': it['at'],
      'ct': it['ct'],
      'mt': it['mt'],
      'pt': it['pt'],
    });

    final metadata = _pruneEmpty({
      'ogTitle': social['title'],
      'ogDescription': social['description'],
      'ogImage': social['imageUrl'],
    });

    return _pruneEmpty({
      'type': 'unified',
      'slug': link['slug'],
      'fallbackUrl': fallbackUrl,
      'iosUrl': iosUrl,
      'androidUrl': androidUrl,
      'allowQueryPassthrough': true,
      'parameters': parameters.isNotEmpty ? parameters : null,
      'metadata': metadata.isNotEmpty ? metadata : null,
    });
  }

  /// Dry-run: build the would-create result (incl. the real SDK payload) offline.
  static CreateOutcome previewCreate(Map<String, dynamic> link) {
    return CreateOutcome(
      status: 'preview',
      shortLink: _shortUrlFor(link),
      payload: toSdkPayload(link),
      link: link,
    );
  }

  /// Live create against POST /sdk/links. Requires an API key.
  Future<CreateOutcome> liveCreate(
    Map<String, dynamic> link, {
    required String apiKey,
  }) async {
    final payload = toSdkPayload(link);
    final res = await _http.post(
      Uri.parse('$apiBase/sdk/links'),
      headers: {'content-type': 'application/json', 'x-app-key': apiKey},
      body: jsonEncode(payload),
    );
    final text = res.body;
    Map<String, dynamic> body;
    try {
      body = text.isNotEmpty
          ? (jsonDecode(text) as Map<String, dynamic>)
          : <String, dynamic>{};
    } catch (_) {
      body = {'raw': text};
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final msg = body['message'] ?? body['error'] ?? (text.isNotEmpty ? text : 'HTTP ${res.statusCode}');
      throw Exception('ULink API ${res.statusCode}: $msg');
    }
    return CreateOutcome(
      status: 'created',
      shortLink: (body['shortUrl'] as String?) ?? _shortUrlFor(link),
      payload: payload,
      link: body,
    );
  }

  /// Resolve a created link via GET /sdk/resolve. Returns the resolved link
  /// body for live parity verification, or null if unreachable. This is the
  /// lenient form the importer uses: any failure degrades to null so a live
  /// import still completes.
  Future<Map<String, dynamic>?> liveResolve(
    String shortUrl, {
    String? apiKey,
  }) async {
    final r = await resolve(shortUrl, apiKey: apiKey);
    return r.ok ? r.body : null;
  }

  /// Resolve a short URL via GET /sdk/resolve, surfacing the outcome explicitly
  /// so callers can tell a genuine 404 from a transport error.
  Future<ResolveOutcome> resolve(String shortUrl, {String? apiKey}) async {
    final url = RegExp(r'^https?://', caseSensitive: false).hasMatch(shortUrl)
        ? shortUrl
        : 'https://$shortUrl';
    http.Response res;
    try {
      res = await _http.get(
        Uri.parse('$apiBase/sdk/resolve?url=${Uri.encodeComponent(url)}'),
        headers: apiKey != null ? {'x-app-key': apiKey} : {},
      );
    } catch (e) {
      return ResolveOutcome(ok: false, status: 0, body: null, error: '$e');
    }
    final text = res.body;
    Map<String, dynamic>? body;
    try {
      body = text.isNotEmpty ? (jsonDecode(text) as Map<String, dynamic>) : null;
    } catch (_) {
      body = {'raw': text};
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final msg = body?['message'] ??
          body?['error'] ??
          'HTTP ${res.statusCode}';
      return ResolveOutcome(
          ok: false, status: res.statusCode, body: body, error: '$msg');
    }
    return ResolveOutcome(ok: true, status: res.statusCode, body: body);
  }

  void close() => _http.close();
}

