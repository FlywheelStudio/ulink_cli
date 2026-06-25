// Parsers for the real-world shapes a developer's Firebase Dynamic Links (FDL)
// export can take. We normalize all of them into a single canonical
// `DynamicLinkInfo`-shaped map so the mapper has one input contract.
//
// Supported inputs (auto-detected):
//   1. A `DynamicLinkInfo` JSON object (the FDL REST create-request body shape).
//   2. The create-request wrapper: `{ dynamicLinkInfo: { ... }, shortLink?, ... }`.
//   3. A batch wrapper: `{ links: [ <any of the above> ] }` or a bare JSON array.
//   4. An FDL long/short link URL using manual-construction query params
//      (link, apn, afl, amv, ibi, ifl, ius, isi, imv, ipbi, ipfl, efr, ofl,
//       st, sd, si, utm_*, gclid, at, ct, mt, pt). This covers the very common
//      case where a developer has a list of `*.page.link` URLs and nothing else.
//   5. A CSV with a header row — the "I exported my link inventory to a
//      spreadsheet" case. Recognized columns map to DynamicLinkInfo fields
//      (link, shortLink, apn/androidPackageName, ibi/iosBundleId, utmSource, …);
//      a column that holds full FDL long-link URLs is parsed via the URL path.
//
// This is a faithful Dart port of the Node `@ulink/cli` `src/fdl/parse.js`.

import 'dart:convert';

/// Thrown for any malformed or unrecognized FDL export input.
class FdlParseError implements Exception {
  final String message;
  FdlParseError(this.message);
  @override
  String toString() => 'FdlParseError: $message';
}

/// Remove null / empty-string / empty-map entries (shallow). Mirrors the JS
/// `clean()` so mapping + parity stay byte-for-byte equivalent to the TS source.
Map<String, dynamic> clean(Map<String, dynamic> obj) {
  final out = <String, dynamic>{};
  obj.forEach((k, v) {
    if (v == null || v == '') return;
    if (v is Map && v.isEmpty) return;
    out[k] = v;
  });
  return out;
}

/// Map of FDL long-link query params -> canonical DynamicLinkInfo paths.
Map<String, dynamic> _fromQueryParams(Map<String, String> params) {
  String? get(String k) {
    final v = params[k];
    return (v == null || v == '') ? null : v;
  }

  final link = get('link');
  if (link == null) {
    throw FdlParseError(
      'FDL URL is missing the required `link` parameter (the deep link destination).',
    );
  }
  final info = <String, dynamic>{
    'link': link,
    'androidInfo': clean({
      'androidPackageName': get('apn'),
      'androidFallbackLink': get('afl'),
      'androidMinPackageVersionCode': get('amv'),
    }),
    'iosInfo': clean({
      'iosBundleId': get('ibi'),
      'iosFallbackLink': get('ifl'),
      'iosCustomScheme': get('ius'),
      'iosIpadFallbackLink': get('ipfl'),
      'iosIpadBundleId': get('ipbi'),
      'iosAppStoreId': get('isi'),
      'iosMinimumVersion': get('imv'),
    }),
    'navigationInfo': clean({
      // efr=1 means "skip the app preview page" -> forced redirect on.
      'enableForcedRedirect': get('efr') == '1' ? true : null,
    }),
    'analyticsInfo': clean({
      'googlePlayAnalytics': clean({
        'utmSource': get('utm_source'),
        'utmMedium': get('utm_medium'),
        'utmCampaign': get('utm_campaign'),
        'utmTerm': get('utm_term'),
        'utmContent': get('utm_content'),
        'gclid': get('gclid'),
      }),
      'itunesConnectAnalytics': clean({
        'at': get('at'),
        'ct': get('ct'),
        'mt': get('mt'),
        'pt': get('pt'),
      }),
    }),
    'socialMetaTagInfo': clean({
      'socialTitle': get('st'),
      'socialDescription': get('sd'),
      'socialImageLink': get('si'),
    }),
  };
  // `ofl` (other-platform fallback link) has no DynamicLinkInfo field; carry it
  // through under a namespaced key so the mapper can use it for desktop/web.
  final ofl = get('ofl');
  if (ofl != null) info['otherFallbackLink'] = ofl;
  return info;
}

/// FDL export parsing. All static — mirrors the module-level JS functions.
class FdlParser {
  /// Parse a single FDL URL string into a canonical link map.
  static Map<String, dynamic> parseUrl(String url) {
    final Uri u;
    try {
      u = Uri.parse(url);
    } catch (_) {
      throw FdlParseError('Not a valid URL: $url');
    }
    if (!u.hasScheme || u.host.isEmpty) {
      throw FdlParseError('Not a valid URL: $url');
    }
    final info = _fromQueryParams(u.queryParameters);
    info['shortLink'] = url;
    info['domainUriPrefix'] = '${u.scheme}://${u.host}';
    return info;
  }

  /// Normalize one object (DynamicLinkInfo or a wrapper) into a canonical link.
  static Map<String, dynamic> _normalizeObject(dynamic obj) {
    if (obj is String) return parseUrl(obj);
    if (obj is! Map) {
      throw FdlParseError('Expected an FDL link object or URL string.');
    }
    final src = Map<String, dynamic>.from(obj);
    // Create-request wrapper: { dynamicLinkInfo, shortLink, ... }
    final info = src['dynamicLinkInfo'] is Map
        ? Map<String, dynamic>.from(src['dynamicLinkInfo'] as Map)
        : Map<String, dynamic>.from(src);
    if (src['shortLink'] != null && info['shortLink'] == null) {
      info['shortLink'] = src['shortLink'];
    }

    if (info['link'] == null) {
      throw FdlParseError(
        'FDL link object is missing the required `link` field (the deep link destination).',
      );
    }
    // Ensure nested groups exist so downstream code can read them safely.
    info['androidInfo'] = clean(_asMap(info['androidInfo']));
    info['iosInfo'] = clean(_asMap(info['iosInfo']));
    info['navigationInfo'] = clean(_asMap(info['navigationInfo']));
    final analytics = _asMap(info['analyticsInfo']);
    info['analyticsInfo'] = {
      'googlePlayAnalytics': clean(_asMap(analytics['googlePlayAnalytics'])),
      'itunesConnectAnalytics': clean(_asMap(analytics['itunesConnectAnalytics'])),
    };
    info['socialMetaTagInfo'] = clean(_asMap(info['socialMetaTagInfo']));
    return info;
  }

  static Map<String, dynamic> _asMap(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  /// Parse raw export text (JSON, CSV, or newline-delimited URLs) into links.
  static List<Map<String, dynamic>> parseExport(String raw) {
    final text = raw.trim();
    if (text.isEmpty) throw FdlParseError('Export is empty.');

    // Try JSON first.
    if (text[0] == '{' || text[0] == '[') {
      final dynamic json;
      try {
        json = jsonDecode(text);
      } catch (e) {
        throw FdlParseError('Export looks like JSON but failed to parse: $e');
      }
      final List<dynamic> arr;
      if (json is List) {
        arr = json;
      } else if (json is Map && json['links'] is List) {
        arr = json['links'] as List;
      } else if (json is Map && json['shortLinks'] is List) {
        arr = json['shortLinks'] as List;
      } else {
        arr = [json];
      }
      if (arr.isEmpty) throw FdlParseError('Export contained zero links.');
      final out = <Map<String, dynamic>>[];
      for (var i = 0; i < arr.length; i++) {
        try {
          out.add(_normalizeObject(arr[i]));
        } on FdlParseError catch (e) {
          throw FdlParseError('Link #${i + 1}: ${e.message}');
        }
      }
      return out;
    }

    // Otherwise treat as newline-delimited content (ignore blanks/# comments).
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('#'))
        .toList();
    if (lines.isEmpty) throw FdlParseError('Export contained zero links.');

    // A CSV export has a header row: the first content line has a comma and does
    // NOT start with a URL (header cells are column names). A bare-URL list and
    // an FDL long-link list both start with `http`, so they stay on the URL path
    // even though long links contain commas in their query values.
    final first = lines[0];
    if (first.contains(',') &&
        !RegExp(r'^https?://', caseSensitive: false).hasMatch(first)) {
      return parseCsv(lines);
    }

    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < lines.length; i++) {
      try {
        out.add(parseUrl(lines[i]));
      } on FdlParseError catch (e) {
        throw FdlParseError('Line #${i + 1}: ${e.message}');
      }
    }
    return out;
  }

  /// Parse CSV content lines (header + rows) into canonical links.
  static List<Map<String, dynamic>> parseCsv(List<String> lines) {
    final header = _splitCsvLine(lines[0]);
    // Map each header column index -> canonical key (or null if unrecognized).
    final colKey = header.map((h) {
      final n = _normHeader(h);
      for (final entry in _csvColumns.entries) {
        if (entry.value.contains(n)) return entry.key;
      }
      return null;
    }).toList();
    if (!colKey.any((k) => k != null)) {
      throw FdlParseError(
        'CSV header has no recognized columns. Expected at least a "link" column '
        '(the deep-link destination); got: ${header.join(', ')}',
      );
    }

    final rows = lines.sublist(1);
    if (rows.isEmpty) throw FdlParseError('CSV had a header but no data rows.');

    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < rows.length; i++) {
      final cells = _splitCsvLine(rows[i]);
      String? val(String key) {
        final idx = colKey.indexOf(key);
        final v = idx == -1 ? null : (idx < cells.length ? cells[idx] : null);
        return (v == null || v == '') ? null : v;
      }

      final linkVal = val('link');
      final shortVal = val('shortlink');
      try {
        // Convenience: if there's no destination column but the short/url column
        // holds a full FDL long link (with its own ?link=... params), parse that.
        if (linkVal == null &&
            shortVal != null &&
            RegExp(r'[?&]link=').hasMatch(shortVal)) {
          out.add(parseUrl(shortVal));
          continue;
        }
        final info = <String, dynamic>{
          'link': linkVal,
          'shortLink': shortVal,
          'androidInfo': {
            'androidPackageName': val('apn'),
            'androidFallbackLink': val('afl'),
            'androidMinPackageVersionCode': val('amv'),
          },
          'iosInfo': {
            'iosBundleId': val('ibi'),
            'iosAppStoreId': val('isi'),
            'iosFallbackLink': val('ifl'),
            'iosCustomScheme': val('ius'),
            'iosMinimumVersion': val('imv'),
            'iosIpadBundleId': val('ipbi'),
            'iosIpadFallbackLink': val('ipfl'),
          },
          'navigationInfo': <String, dynamic>{},
          'analyticsInfo': {
            'googlePlayAnalytics': {
              'utmSource': val('utm_source'),
              'utmMedium': val('utm_medium'),
              'utmCampaign': val('utm_campaign'),
              'utmTerm': val('utm_term'),
              'utmContent': val('utm_content'),
              'gclid': val('gclid'),
            },
            'itunesConnectAnalytics': {
              'at': val('at'),
              'ct': val('ct'),
              'mt': val('mt'),
              'pt': val('pt'),
            },
          },
          'socialMetaTagInfo': {
            'socialTitle': val('st'),
            'socialDescription': val('sd'),
            'socialImageLink': val('si'),
          },
        };
        if (val('ofl') != null) info['otherFallbackLink'] = val('ofl');
        out.add(_normalizeObject(info));
      } on FdlParseError catch (e) {
        throw FdlParseError('Row #${i + 1}: ${e.message}');
      }
    }
    return out;
  }
}

/// Header alias -> canonical FDL field. Keys are normalized (lowercased, all
/// non-alphanumerics stripped) so `iOS Bundle ID`, `ios_bundle_id` and `ibi`
/// all collapse to the same column.
const Map<String, List<String>> _csvColumns = {
  'link': ['link', 'deeplink', 'destination', 'target', 'targeturl'],
  'shortlink': [
    'shortlink', 'short', 'shorturl', 'fdllink', 'fdlurl', 'dynamiclink',
    'dynamiclinkurl', 'url', 'longlink',
  ],
  'apn': ['apn', 'androidpackagename', 'androidpackage', 'packagename', 'package'],
  'afl': ['afl', 'androidfallbacklink', 'androidfallback'],
  'amv': ['amv', 'androidminpackageversioncode', 'androidminversion'],
  'ibi': ['ibi', 'iosbundleid', 'bundleid', 'iosbundle'],
  'isi': ['isi', 'iosappstoreid', 'appstoreid'],
  'ifl': ['ifl', 'iosfallbacklink', 'iosfallback'],
  'ius': ['ius', 'ioscustomscheme', 'customscheme'],
  'imv': ['imv', 'iosminimumversion', 'iosminversion'],
  'ipbi': ['ipbi', 'iosipadbundleid'],
  'ipfl': ['ipfl', 'iosipadfallbacklink'],
  'utm_source': ['utmsource'],
  'utm_medium': ['utmmedium'],
  'utm_campaign': ['utmcampaign'],
  'utm_term': ['utmterm'],
  'utm_content': ['utmcontent'],
  'gclid': ['gclid'],
  'at': ['at', 'itunesat'],
  'ct': ['ct', 'itunesct'],
  'mt': ['mt'],
  'pt': ['pt'],
  'st': ['st', 'socialtitle'],
  'sd': ['sd', 'socialdescription'],
  'si': ['si', 'socialimagelink', 'socialimage'],
  'ofl': ['ofl', 'otherfallbacklink', 'desktopfallback', 'webfallback'],
};

String _normHeader(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

/// Split one CSV line into fields, honoring "double quoted" cells with commas.
List<String> _splitCsvLine(String line) {
  final out = <String>[];
  var field = '';
  var quoted = false;
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (quoted) {
      if (ch == '"') {
        if (i + 1 < line.length && line[i + 1] == '"') {
          field += '"';
          i++; // escaped quote
        } else {
          quoted = false;
        }
      } else {
        field += ch;
      }
    } else if (ch == '"') {
      quoted = true;
    } else if (ch == ',') {
      out.add(field);
      field = '';
    } else {
      field += ch;
    }
  }
  out.add(field);
  return out.map((f) => f.trim()).toList();
}

