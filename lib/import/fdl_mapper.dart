// Maps a canonical FDL link (see fdl_parser.dart) to a ULink link definition.
//
// The mapping is intentionally lossless for everything that affects *routing*
// and *attribution*, because parity on those two axes is the whole point of the
// importer. The ULink link map below is the contract the ULink backend consumes
// when creating links (see ../api/sdk_links_client.dart).
//
// Faithful Dart port of the Node `@ulink/cli` `src/map/to-ulink.js`.

import 'fdl_parser.dart' show clean;

class FdlMapper {
  /// Derive a short-code slug. If the original FDL short link is known we reuse
  /// its path so existing printed/QR/deep-linked URLs keep the same suffix;
  /// otherwise we deterministically derive one from the index so re-runs are
  /// stable.
  static String deriveSlug(Map<String, dynamic> fdl, int index) {
    final shortLink = fdl['shortLink'] as String?;
    if (shortLink != null) {
      try {
        final p = Uri.parse(shortLink).path.replaceFirst(RegExp(r'^/+'), '');
        if (p.isNotEmpty) return p;
      } catch (_) {
        // fall through
      }
    }
    return 'imported-${index + 1}';
  }

  /// Map a canonical FDL link to a ULink link definition.
  static Map<String, dynamic> mapToUlink(
    Map<String, dynamic> fdl, {
    required String domain,
    int index = 0,
    String? slug,
  }) {
    final android = _m(fdl['androidInfo']);
    final ios = _m(fdl['iosInfo']);
    final nav = _m(fdl['navigationInfo']);
    final analytics = _m(fdl['analyticsInfo']);
    final gpa = _m(analytics['googlePlayAnalytics']);
    final itc = _m(analytics['itunesConnectAnalytics']);
    final social = _m(fdl['socialMetaTagInfo']);

    final routing = clean({
      'android': clean({
        'packageName': android['androidPackageName'],
        'fallbackUrl': android['androidFallbackLink'],
        'minVersion': android['androidMinPackageVersionCode'],
      }),
      'ios': clean({
        'bundleId': ios['iosBundleId'],
        'appStoreId': ios['iosAppStoreId'],
        'fallbackUrl': ios['iosFallbackLink'],
        'customScheme': ios['iosCustomScheme'],
        'minVersion': ios['iosMinimumVersion'],
        'ipad': clean({
          'bundleId': ios['iosIpadBundleId'],
          'fallbackUrl': ios['iosIpadFallbackLink'],
        }),
      }),
      'desktop': clean({
        // FDL `ofl` is the cross-platform (desktop/web) fallback.
        'fallbackUrl': fdl['otherFallbackLink'],
      }),
      // FDL `efr=1` / enableForcedRedirect skips the app-preview interstitial.
      'forceRedirect':
          nav['enableForcedRedirect'] == true || nav['enableForcedRedirect'] == '1',
    });

    final attribution = clean({
      'utm': clean({
        'source': gpa['utmSource'],
        'medium': gpa['utmMedium'],
        'campaign': gpa['utmCampaign'],
        'term': gpa['utmTerm'],
        'content': gpa['utmContent'],
      }),
      'gclid': gpa['gclid'],
      'itunes': clean({
        'at': itc['at'], // affiliate token
        'ct': itc['ct'], // campaign token
        'mt': itc['mt'], // media type
        'pt': itc['pt'], // provider token
      }),
    });

    return clean({
      'slug': slug ?? deriveSlug(fdl, index),
      'domain': domain,
      'destination': fdl['link'],
      'routing': routing,
      'social': clean({
        'title': social['socialTitle'],
        'description': social['socialDescription'],
        'imageUrl': social['socialImageLink'],
      }),
      'attribution': attribution,
      'source': clean({
        'provider': 'firebase-dynamic-links',
        'originalShortLink': fdl['shortLink'],
        'originalDomainUriPrefix': fdl['domainUriPrefix'],
      }),
    });
  }

  static Map<String, dynamic> _m(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
}

