/// ULink project configuration from API
class ProjectConfig {
  final String projectId;
  final String? iosBundleIdentifier;
  final String? iosTeamId;
  final String? iosDeeplinkSchema;
  final String? androidPackageName;
  final List<String> androidSha256Fingerprints;
  final String? androidDeeplinkSchema;
  final List<DomainConfig> domains;

  ProjectConfig({
    required this.projectId,
    this.iosBundleIdentifier,
    this.iosTeamId,
    this.iosDeeplinkSchema,
    this.androidPackageName,
    this.androidSha256Fingerprints = const [],
    this.androidDeeplinkSchema,
    this.domains = const [],
  });

  factory ProjectConfig.fromJson(Map<String, dynamic> json) {
    return ProjectConfig(
      projectId: json['projectId'] as String,
      iosBundleIdentifier: json['ios_bundle_identifier'] as String?,
      iosTeamId: json['ios_team_id'] as String?,
      iosDeeplinkSchema: json['ios_deeplink_schema'] as String?,
      androidPackageName: json['android_package_name'] as String?,
      androidSha256Fingerprints:
          (json['android_sha256_fingerprints'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      androidDeeplinkSchema: json['android_deeplink_schema'] as String?,
      domains:
          (json['domains'] as List<dynamic>?)
              ?.map((e) => DomainConfig.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// Domain configuration
class DomainConfig {
  final String id;
  final String host;
  final String status; // 'verified', 'pending', 'failed'
  final bool isPrimary;

  DomainConfig({
    required this.id,
    required this.host,
    required this.status,
    this.isPrimary = false,
  });

  factory DomainConfig.fromJson(Map<String, dynamic> json) {
    return DomainConfig(
      id: json['id'] as String,
      host: json['host'] as String,
      status: json['status'] as String? ?? 'pending',
      isPrimary: json['isPrimary'] as bool? ?? false,
    );
  }
}
