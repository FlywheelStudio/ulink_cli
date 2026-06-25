// Parity verification: prove that a recreated ULink link preserves the exact
// routing and attribution behavior of the original FDL link.
//
// We build a normalized "parity profile" independently from each side (the FDL
// source and the ULink definition) and compare them field-by-field. Because the
// two profiles are derived from different code paths, a mismatch reliably
// surfaces a mapping bug rather than tautologically passing.
//
// Faithful Dart port of the Node `@ulink/cli` `src/verify/parity.js`.

const List<String> _attributionKeys = [
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

/// A single field comparison between FDL source and ULink definition.
class ParityCheck {
  final String field;
  final dynamic fdl;
  final dynamic ulink;
  final bool ok;
  ParityCheck(this.field, this.fdl, this.ulink) : ok = fdl == ulink;
}

/// Result of comparing a sent payload against a resolved (live) link.
class LiveCheck {
  final String field;
  final dynamic sent;
  final dynamic resolved;
  final bool ok;
  LiveCheck(this.field, this.sent, this.resolved) : ok = sent == resolved;
}

class ParityResult {
  final List<ParityCheck> checks;
  ParityResult(this.checks);
  bool get ok => checks.every((c) => c.ok);
  List<ParityCheck> get failures => checks.where((c) => !c.ok).toList();
}

class LiveParityResult {
  final List<LiveCheck> checks;
  LiveParityResult(this.checks);
  bool get ok => checks.every((c) => c.ok);
  List<LiveCheck> get failures => checks.where((c) => !c.ok).toList();
}

String? _norm(dynamic v) =>
    (v == null || v == '') ? null : v.toString();

Map<String, dynamic> _m(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

class ImportParity {
  /// Parity profile from the canonical FDL link.
  static Map<String, dynamic> fdlProfile(Map<String, dynamic> fdl) {
    final a = _m(fdl['androidInfo']);
    final i = _m(fdl['iosInfo']);
    final nav = _m(fdl['navigationInfo']);
    final analytics = _m(fdl['analyticsInfo']);
    final gpa = _m(analytics['googlePlayAnalytics']);
    final itc = _m(analytics['itunesConnectAnalytics']);
    final s = _m(fdl['socialMetaTagInfo']);
    return {
      'destination': _norm(fdl['link']),
      'android': {
        'app': _norm(a['androidPackageName']),
        'fallback': _norm(a['androidFallbackLink']),
        'minVersion': _norm(a['androidMinPackageVersionCode']),
      },
      'ios': {
        'app': _norm(i['iosBundleId']),
        'appStore': _norm(i['iosAppStoreId']),
        'fallback': _norm(i['iosFallbackLink']),
        'scheme': _norm(i['iosCustomScheme']),
        'minVersion': _norm(i['iosMinimumVersion']),
      },
      'ipad': {
        'app': _norm(i['iosIpadBundleId']),
        'fallback': _norm(i['iosIpadFallbackLink']),
      },
      'desktop': {'fallback': _norm(fdl['otherFallbackLink'])},
      'forceRedirect': nav['enableForcedRedirect'] == true ||
          nav['enableForcedRedirect'] == '1',
      'social': {
        'title': _norm(s['socialTitle']),
        'description': _norm(s['socialDescription']),
        'image': _norm(s['socialImageLink']),
      },
      'attribution': {
        'utm_source': _norm(gpa['utmSource']),
        'utm_medium': _norm(gpa['utmMedium']),
        'utm_campaign': _norm(gpa['utmCampaign']),
        'utm_term': _norm(gpa['utmTerm']),
        'utm_content': _norm(gpa['utmContent']),
        'gclid': _norm(gpa['gclid']),
        'at': _norm(itc['at']),
        'ct': _norm(itc['ct']),
        'mt': _norm(itc['mt']),
        'pt': _norm(itc['pt']),
      },
    };
  }

  /// Parity profile from the produced ULink link definition.
  static Map<String, dynamic> ulinkProfile(Map<String, dynamic> link) {
    final r = _m(link['routing']);
    final a = _m(r['android']);
    final i = _m(r['ios']);
    final ipad = _m(i['ipad']);
    final d = _m(r['desktop']);
    final at = _m(link['attribution']);
    final utm = _m(at['utm']);
    final it = _m(at['itunes']);
    final s = _m(link['social']);
    return {
      'destination': _norm(link['destination']),
      'android': {
        'app': _norm(a['packageName']),
        'fallback': _norm(a['fallbackUrl']),
        'minVersion': _norm(a['minVersion']),
      },
      'ios': {
        'app': _norm(i['bundleId']),
        'appStore': _norm(i['appStoreId']),
        'fallback': _norm(i['fallbackUrl']),
        'scheme': _norm(i['customScheme']),
        'minVersion': _norm(i['minVersion']),
      },
      'ipad': {
        'app': _norm(ipad['bundleId']),
        'fallback': _norm(ipad['fallbackUrl']),
      },
      'desktop': {'fallback': _norm(d['fallbackUrl'])},
      'forceRedirect': r['forceRedirect'] == true,
      'social': {
        'title': _norm(s['title']),
        'description': _norm(s['description']),
        'image': _norm(s['imageUrl']),
      },
      'attribution': {
        'utm_source': _norm(utm['source']),
        'utm_medium': _norm(utm['medium']),
        'utm_campaign': _norm(utm['campaign']),
        'utm_term': _norm(utm['term']),
        'utm_content': _norm(utm['content']),
        'gclid': _norm(at['gclid']),
        'at': _norm(it['at']),
        'ct': _norm(it['ct']),
        'mt': _norm(it['mt']),
        'pt': _norm(it['pt']),
      },
    };
  }

  /// Compare an FDL canonical link against its ULink definition (static parity).
  static ParityResult verifyParity(
    Map<String, dynamic> fdl,
    Map<String, dynamic> link,
  ) {
    final f = fdlProfile(fdl);
    final u = ulinkProfile(link);
    final checks = <ParityCheck>[];
    void cmp(String field, dynamic a, dynamic b) =>
        checks.add(ParityCheck(field, a, b));

    final fa = _m(f['android']), ua = _m(u['android']);
    final fi = _m(f['ios']), ui = _m(u['ios']);
    final fp = _m(f['ipad']), up = _m(u['ipad']);
    final fd = _m(f['desktop']), ud = _m(u['desktop']);
    final fs = _m(f['social']), us = _m(u['social']);
    final fat = _m(f['attribution']), uat = _m(u['attribution']);

    cmp('destination', f['destination'], u['destination']);
    cmp('routing.android.app', fa['app'], ua['app']);
    cmp('routing.android.fallback', fa['fallback'], ua['fallback']);
    cmp('routing.android.minVersion', fa['minVersion'], ua['minVersion']);
    cmp('routing.ios.app', fi['app'], ui['app']);
    cmp('routing.ios.appStore', fi['appStore'], ui['appStore']);
    cmp('routing.ios.fallback', fi['fallback'], ui['fallback']);
    cmp('routing.ios.scheme', fi['scheme'], ui['scheme']);
    cmp('routing.ios.minVersion', fi['minVersion'], ui['minVersion']);
    cmp('routing.ipad.app', fp['app'], up['app']);
    cmp('routing.ipad.fallback', fp['fallback'], up['fallback']);
    cmp('routing.desktop.fallback', fd['fallback'], ud['fallback']);
    cmp('routing.forceRedirect', f['forceRedirect'], u['forceRedirect']);
    cmp('social.title', fs['title'], us['title']);
    cmp('social.description', fs['description'], us['description']);
    cmp('social.image', fs['image'], us['image']);
    for (final k in _attributionKeys) {
      cmp('attribution.$k', fat[k], uat[k]);
    }

    return ParityResult(checks);
  }

  // Routing fields the live edge echoes back via GET /sdk/resolve. These are the
  // per-platform destinations the deployed short link will actually send users
  // to, so matching them against what we sent is the live analogue of the static
  // routing parity above. (Attribution rides in `parameters`/passthrough, which
  // /sdk/resolve does not echo, so attribution stays covered by verifyParity.)
  static const List<String> liveRoutingFields = [
    'type',
    'slug',
    'fallbackUrl',
    'iosUrl',
    'androidUrl',
  ];

  /// Compare the `/sdk/links` payload we sent against the `/sdk/resolve`
  /// response the deployed edge returns for the created short link.
  static LiveParityResult verifyLiveRouting(
    Map<String, dynamic> sent,
    Map<String, dynamic> resolved,
  ) {
    final checks = liveRoutingFields
        .map((field) => LiveCheck(field, _norm(sent[field]), _norm(resolved[field])))
        .toList();
    return LiveParityResult(checks);
  }
}

