import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/verification_result.dart';

/// A single `android_app` statement from an `assetlinks.json` file: the
/// declared package and its SHA-256 certificate fingerprints.
class AssetlinksApp {
  final String package;
  final List<String> fingerprints;
  AssetlinksApp(this.package, this.fingerprints);
}

/// Tester for well-known files (AASA and Asset Links).
///
/// The instance verdict methods ([testAasaFile] / [testAssetLinksFile]) back
/// the credentialed project-config `verify` flow. The pure static extractors
/// below ([extractAasaAppIds] / [extractAssetlinksApps] / [normalizeFingerprint])
/// are the shared, single-source-of-truth parsing primitives reused by the
/// standalone `verify --domain` command (see `DomainVerifyCommand`), so the
/// AASA/assetlinks shape is only understood in one place.
class WellKnownTester {
  /// Collect every iOS App ID declared in an AASA file. Mirrors the Node
  /// `aasaAppIds()` in `@ulink/cli` `src/commands/verify.js`: v1 `applinks`
  /// `details[].appID`/`details[].appIDs[]` plus the legacy `applinks.apps[]`.
  static List<String> extractAasaAppIds(Map<String, dynamic>? json) {
    final al = json?['applinks'];
    if (al is! Map) return const [];
    final ids = <String>{};
    final details = al['details'];
    if (details is List) {
      for (final d in details) {
        if (d is Map) {
          final appId = d['appID'];
          if (appId is String) ids.add(appId);
          final appIds = d['appIDs'];
          if (appIds is List) {
            for (final a in appIds) {
              if (a is String) ids.add(a);
            }
          }
        }
      }
    }
    final apps = al['apps'];
    if (apps is List) {
      for (final a in apps) {
        if (a is String) ids.add(a);
      }
    }
    return ids.toList();
  }

  /// Collect the `{package, fingerprints}` entries from an `assetlinks.json`
  /// file. Mirrors the Node `assetlinksApps()` in `src/commands/verify.js`.
  static List<AssetlinksApp> extractAssetlinksApps(dynamic json) {
    final out = <AssetlinksApp>[];
    if (json is List) {
      for (final stmt in json) {
        if (stmt is Map) {
          final t = stmt['target'];
          if (t is Map &&
              t['namespace'] == 'android_app' &&
              t['package_name'] is String) {
            final fps = <String>[];
            final raw = t['sha256_cert_fingerprints'];
            if (raw is List) {
              for (final f in raw) {
                fps.add(f.toString());
              }
            }
            out.add(AssetlinksApp(t['package_name'] as String, fps));
          }
        }
      }
    }
    return out;
  }

  /// Canonicalize a SHA-256 fingerprint for comparison: drop `:` separators and
  /// lower-case. Mirrors `normFp()` in the Node `src/commands/verify.js`.
  static String normalizeFingerprint(String s) =>
      s.replaceAll(':', '').toLowerCase();

  /// Test Apple App Site Association (AASA) file
  static Future<VerificationResult> testAasaFile(
    String domain,
    String? teamId,
    String? bundleIdentifier,
  ) async {
    final url = Uri.parse(
      'https://$domain/.well-known/apple-app-site-association',
    );

    try {
      final response = await http.get(
        url,
        headers: {'Accept': 'application/json'},
      );

      // Check status code
      if (response.statusCode != 200) {
        return VerificationResult(
          checkName: 'AASA File Accessibility',
          status: VerificationStatus.error,
          message: 'AASA file returned status ${response.statusCode}',
          fixSuggestion:
              'Ensure the AASA file is accessible at https://$domain/.well-known/apple-app-site-association',
          details: {'statusCode': response.statusCode, 'url': url.toString()},
        );
      }

      // Check Content-Type
      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.contains('application/json') &&
          !contentType.contains('application/pkcs7-mime')) {
        return VerificationResult(
          checkName: 'AASA File Content-Type',
          status: VerificationStatus.warning,
          message:
              'AASA file Content-Type is "$contentType" (expected application/json)',
          fixSuggestion:
              'Ensure the server returns Content-Type: application/json for the AASA file',
          details: {'contentType': contentType},
        );
      }

      // Parse JSON
      Map<String, dynamic> json;
      try {
        json = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (e) {
        return VerificationResult(
          checkName: 'AASA File JSON Validity',
          status: VerificationStatus.error,
          message: 'AASA file is not valid JSON: $e',
          fixSuggestion: 'Ensure the AASA file is valid JSON',
        );
      }

      // Check applinks structure
      final applinks = json['applinks'] as Map<String, dynamic>?;
      if (applinks == null) {
        return VerificationResult(
          checkName: 'AASA File Structure',
          status: VerificationStatus.error,
          message: 'AASA file missing "applinks" key',
          fixSuggestion: 'Ensure the AASA file contains an "applinks" object',
        );
      }

      final details = applinks['details'] as List<dynamic>?;
      if (details == null || details.isEmpty) {
        return VerificationResult(
          checkName: 'AASA File Structure',
          status: VerificationStatus.error,
          message: 'AASA file missing "applinks.details" array',
          fixSuggestion: 'Ensure the AASA file contains applinks.details array',
        );
      }

      // Check if bundle identifier and team ID match
      if (teamId != null && bundleIdentifier != null) {
        final expectedAppId = '$teamId.$bundleIdentifier';
        bool foundMatch = false;

        for (final detail in details) {
          if (detail is Map<String, dynamic>) {
            final appId = detail['appID'] as String?;
            if (appId == expectedAppId) {
              foundMatch = true;
              break;
            }
          }
        }

        if (!foundMatch) {
          return VerificationResult(
            checkName: 'AASA File App ID Match',
            status: VerificationStatus.error,
            message: 'AASA file does not contain appID "$expectedAppId"',
            fixSuggestion:
                'Ensure the AASA file contains an entry with appID "$expectedAppId"',
            details: {'expectedAppId': expectedAppId},
          );
        }
      }

      return VerificationResult(
        checkName: 'AASA File Verification',
        status: VerificationStatus.success,
        message: 'AASA file is accessible and valid',
        details: {'url': url.toString(), 'domain': domain},
      );
    } catch (e) {
      return VerificationResult(
        checkName: 'AASA File Accessibility',
        status: VerificationStatus.error,
        message: 'Failed to fetch AASA file: $e',
        fixSuggestion:
            'Check network connectivity and ensure the domain is correctly configured',
      );
    }
  }

  /// Test Android Asset Links JSON file
  static Future<VerificationResult> testAssetLinksFile(
    String domain,
    String? packageName,
    List<String>? sha256Fingerprints,
  ) async {
    final url = Uri.parse('https://$domain/.well-known/assetlinks.json');

    try {
      final response = await http.get(
        url,
        headers: {'Accept': 'application/json'},
      );

      // Check status code
      if (response.statusCode != 200) {
        return VerificationResult(
          checkName: 'Asset Links File Accessibility',
          status: VerificationStatus.error,
          message: 'Asset Links file returned status ${response.statusCode}',
          fixSuggestion:
              'Ensure the Asset Links file is accessible at https://$domain/.well-known/assetlinks.json',
          details: {'statusCode': response.statusCode, 'url': url.toString()},
        );
      }

      // Check Content-Type
      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.contains('application/json')) {
        return VerificationResult(
          checkName: 'Asset Links File Content-Type',
          status: VerificationStatus.warning,
          message:
              'Asset Links file Content-Type is "$contentType" (expected application/json)',
          fixSuggestion:
              'Ensure the server returns Content-Type: application/json for the Asset Links file',
          details: {'contentType': contentType},
        );
      }

      // Parse JSON
      List<dynamic> json;
      try {
        json = jsonDecode(response.body) as List<dynamic>;
      } catch (e) {
        return VerificationResult(
          checkName: 'Asset Links File JSON Validity',
          status: VerificationStatus.error,
          message: 'Asset Links file is not valid JSON array: $e',
          fixSuggestion: 'Ensure the Asset Links file is a valid JSON array',
        );
      }

      if (json.isEmpty) {
        return VerificationResult(
          checkName: 'Asset Links File Structure',
          status: VerificationStatus.error,
          message: 'Asset Links file is an empty array',
          fixSuggestion:
              'Ensure the Asset Links file contains at least one entry',
        );
      }

      // Check if package name and fingerprints match
      if (packageName != null &&
          sha256Fingerprints != null &&
          sha256Fingerprints.isNotEmpty) {
        bool foundMatch = false;

        for (final entry in json) {
          if (entry is Map<String, dynamic>) {
            final relation = entry['relation'] as List<dynamic>?;
            final target = entry['target'] as Map<String, dynamic>?;

            if (relation != null &&
                relation.contains(
                  'delegate_permission/common.handle_all_urls',
                ) &&
                target != null) {
              final targetNamespace = target['namespace'] as String?;
              final targetPackageName = target['package_name'] as String?;
              final targetFingerprints =
                  target['sha256_cert_fingerprints'] as List<dynamic>?;

              if (targetNamespace == 'android_app' &&
                  targetPackageName == packageName &&
                  targetFingerprints != null) {
                // Check if at least one fingerprint matches
                final entryFingerprints = targetFingerprints
                    .map((f) => f.toString().toUpperCase())
                    .toList();
                final expectedFingerprints = sha256Fingerprints
                    .map((f) => f.toUpperCase())
                    .toList();

                for (final expected in expectedFingerprints) {
                  if (entryFingerprints.contains(expected)) {
                    foundMatch = true;
                    break;
                  }
                }

                if (foundMatch) break;
              }
            }
          }
        }

        if (!foundMatch) {
          return VerificationResult(
            checkName: 'Asset Links File Package Match',
            status: VerificationStatus.error,
            message:
                'Asset Links file does not contain matching entry for package "$packageName"',
            fixSuggestion:
                'Ensure the Asset Links file contains an entry with:\n'
                '  - package_name: "$packageName"\n'
                '  - sha256_cert_fingerprints: [${sha256Fingerprints.join(", ")}]',
            details: {
              'packageName': packageName,
              'fingerprints': sha256Fingerprints,
            },
          );
        }
      }

      return VerificationResult(
        checkName: 'Asset Links File Verification',
        status: VerificationStatus.success,
        message: 'Asset Links file is accessible and valid',
        details: {'url': url.toString(), 'domain': domain},
      );
    } catch (e) {
      return VerificationResult(
        checkName: 'Asset Links File Accessibility',
        status: VerificationStatus.error,
        message: 'Failed to fetch Asset Links file: $e',
        fixSuggestion:
            'Check network connectivity and ensure the domain is correctly configured',
      );
    }
  }
}
