/// Authentication configuration models
class AuthConfig {
  final AuthType type;
  final String? token; // JWT token
  final String? apiKey; // API key
  final String? refreshToken; // For token refresh
  final DateTime? expiresAt; // Token expiration
  final UserInfo? user;

  AuthConfig({
    required this.type,
    this.token,
    this.apiKey,
    this.refreshToken,
    this.expiresAt,
    this.user,
  });

  factory AuthConfig.fromJson(Map<String, dynamic> json) {
    return AuthConfig(
      type: AuthType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => AuthType.apiKey,
      ),
      token: json['token'] as String?,
      apiKey: json['apiKey'] as String?,
      refreshToken: json['refreshToken'] as String?,
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      user: json['user'] != null
          ? UserInfo.fromJson(json['user'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      if (token != null) 'token': token,
      if (apiKey != null) 'apiKey': apiKey,
      if (refreshToken != null) 'refreshToken': refreshToken,
      if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
      if (user != null) 'user': user!.toJson(),
    };
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }
}

enum AuthType {
  jwt,
  apiKey,
}

/// User information
class UserInfo {
  final String email;
  final String userId;

  UserInfo({
    required this.email,
    required this.userId,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      email: json['email'] as String,
      userId: json['userId'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'userId': userId,
    };
  }
}

/// Project information
class ProjectInfo {
  final String projectId;
  final String projectName;
  final String? apiKey; // Project-specific API key

  ProjectInfo({
    required this.projectId,
    required this.projectName,
    this.apiKey,
  });

  factory ProjectInfo.fromJson(Map<String, dynamic> json) {
    return ProjectInfo(
      projectId: json['projectId'] as String,
      projectName: json['projectName'] as String,
      apiKey: json['apiKey'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'projectId': projectId,
      'projectName': projectName,
      if (apiKey != null) 'apiKey': apiKey,
    };
  }
}

/// Complete CLI configuration
class CliConfig {
  final AuthConfig? auth;
  final List<ProjectInfo> projects;
  final String? supabaseUrl;
  final String? supabaseAnonKey;

  CliConfig({
    this.auth,
    this.projects = const [],
    this.supabaseUrl,
    this.supabaseAnonKey,
  });

  factory CliConfig.fromJson(Map<String, dynamic> json) {
    return CliConfig(
      auth: json['auth'] != null
          ? AuthConfig.fromJson(json['auth'] as Map<String, dynamic>)
          : null,
      projects: (json['projects'] as List<dynamic>?)
              ?.map((p) => ProjectInfo.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      supabaseUrl: json['supabaseUrl'] as String?,
      supabaseAnonKey: json['supabaseAnonKey'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (auth != null) 'auth': auth!.toJson(),
      'projects': projects.map((p) => p.toJson()).toList(),
      if (supabaseUrl != null) 'supabaseUrl': supabaseUrl,
      if (supabaseAnonKey != null) 'supabaseAnonKey': supabaseAnonKey,
    };
  }
}
