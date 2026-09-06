import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import '../api/ulink_api_client.dart';
import '../config/project_config_manager.dart';
import '../utils/console_style.dart';

/// Options for `ulink api-keys <list|create|revoke>`.
class ApiKeysOptions {
  /// One of: list, create, revoke.
  final String action;

  /// Explicit project id. If null it is resolved from the directory config,
  /// then by auto-selecting the only project the user has.
  final String? projectId;

  /// Project directory used to look up the saved project id (default '.').
  final String projectPath;

  /// Key name (create only).
  final String? name;

  /// Key id to revoke (revoke only).
  final String? keyId;

  /// Optional API-key override (rarely useful — key management needs a user).
  final String? apiKey;

  /// Emit machine-readable JSON instead of a table.
  final bool json;

  /// Print usage and exit.
  final bool help;

  ApiKeysOptions({
    required this.action,
    this.projectId,
    this.projectPath = '.',
    this.name,
    this.keyId,
    this.apiKey,
    this.json = false,
    this.help = false,
  });
}

class ApiKeysRunResult {
  final int exitCode;
  ApiKeysRunResult(this.exitCode);
}

/// Manage a project's ULink client SDK API keys from the CLI.
class ApiKeysCommand {
  final String baseUrl;

  ApiKeysCommand({required this.baseUrl});

  Future<ApiKeysRunResult> run(ApiKeysOptions o) async {
    if (o.help) {
      _printUsage();
      return ApiKeysRunResult(0);
    }

    final client = ULinkApiClient(baseUrl: baseUrl, apiKey: o.apiKey);

    try {
      switch (o.action) {
        case 'list':
          return await _list(client, o);
        case 'create':
          return await _create(client, o);
        case 'revoke':
          return await _revoke(client, o);
        default:
          _printUsage();
          return ApiKeysRunResult(2);
      }
    } catch (e) {
      stderr.writeln(ConsoleStyle.error('Error: $e'));
      return ApiKeysRunResult(1);
    }
  }

  Future<ApiKeysRunResult> _list(ULinkApiClient client, ApiKeysOptions o) async {
    final projectId = await _resolveProjectId(client, o);
    if (projectId == null) return ApiKeysRunResult(2);

    final keys = await client.listApiKeys(projectId);

    if (o.json) {
      stdout.writeln(const JsonEncoder.withIndent('  ').convert(keys));
      return ApiKeysRunResult(0);
    }

    if (keys.isEmpty) {
      stdout.writeln(ConsoleStyle.dim(
          'No API keys for this project. Create one: ulink api-keys create --name "<name>"'));
      return ApiKeysRunResult(0);
    }

    stdout.writeln(ConsoleStyle.infoBold('API keys (${keys.length})'));
    stdout.writeln(ConsoleStyle.dim('─' * 50));
    for (final k in keys) {
      final name = _field(k, const ['name', 'label']) ?? '(unnamed)';
      final prefix = _field(k, const ['prefix', 'keyPrefix', 'masked', 'preview']);
      final id = _field(k, const ['id', 'keyId', 'uuid']);
      final created = _field(k, const ['createdAt', 'created_at', 'createdOn']);
      stdout.writeln(ConsoleStyle.bold('  $name'));
      if (prefix != null) stdout.writeln(ConsoleStyle.dim('    key:     $prefix…'));
      if (id != null) stdout.writeln(ConsoleStyle.dim('    id:      $id'));
      if (created != null) stdout.writeln(ConsoleStyle.dim('    created: $created'));
    }
    stdout.writeln(ConsoleStyle.dim('─' * 50));
    stdout.writeln(ConsoleStyle.dim(
        'The full key value is shown only once, at creation time.'));
    return ApiKeysRunResult(0);
  }

  Future<ApiKeysRunResult> _create(
      ULinkApiClient client, ApiKeysOptions o) async {
    final name = o.name?.trim();
    if (name == null || name.isEmpty) {
      stderr.writeln(ConsoleStyle.error(
          'A name is required: ulink api-keys create --name "<name>"'));
      return ApiKeysRunResult(2);
    }

    final projectId = await _resolveProjectId(client, o);
    if (projectId == null) return ApiKeysRunResult(2);

    final created = await client.createApiKey(projectId, name);

    if (o.json) {
      stdout.writeln(const JsonEncoder.withIndent('  ').convert(created));
      return ApiKeysRunResult(0);
    }

    final secret = _field(created, const [
      'key',
      'apiKey',
      'appKey',
      'value',
      'token',
      'secret',
      'plainTextKey',
      'fullKey',
    ]);

    stdout.writeln(ConsoleStyle.success('✓ Created API key "$name"'));
    stdout.writeln('');
    if (secret != null) {
      stdout.writeln(ConsoleStyle.warningBold(
          'Copy this key now — it is shown only once and cannot be retrieved again:'));
      stdout.writeln(ConsoleStyle.bold('  $secret'));
      stdout.writeln('');
      stdout.writeln(ConsoleStyle.dim(
          'Use it to initialize the SDK (e.g. UlinkSDK.initialize(apiKey: ...)).'));
    } else {
      // Schema did not expose a recognizable secret field — show the whole
      // object so the key is never silently dropped.
      stdout.writeln(ConsoleStyle.warning(
          'Could not identify the key field in the response; full response below:'));
      stdout.writeln(const JsonEncoder.withIndent('  ').convert(created));
    }
    return ApiKeysRunResult(0);
  }

  Future<ApiKeysRunResult> _revoke(
      ULinkApiClient client, ApiKeysOptions o) async {
    final keyId = o.keyId?.trim();
    if (keyId == null || keyId.isEmpty) {
      stderr.writeln(ConsoleStyle.error(
          'A key id is required: ulink api-keys revoke <keyId>'));
      return ApiKeysRunResult(2);
    }

    final projectId = await _resolveProjectId(client, o);
    if (projectId == null) return ApiKeysRunResult(2);

    await client.revokeApiKey(keyId, projectId);
    stdout.writeln(ConsoleStyle.success('✓ Revoked API key $keyId'));
    stdout.writeln(ConsoleStyle.dim(
        'Any app still shipping this key will stop authenticating.'));
    return ApiKeysRunResult(0);
  }

  /// Resolve the project id: explicit flag, then saved directory config, then
  /// auto-select when the account has exactly one project. Returns null (after
  /// printing guidance) when it cannot be resolved unambiguously.
  Future<String?> _resolveProjectId(
      ULinkApiClient client, ApiKeysOptions o) async {
    if (o.projectId != null && o.projectId!.isNotEmpty) return o.projectId;

    final saved =
        ProjectConfigManager.loadProjectId(path.absolute(o.projectPath));
    if (saved != null) return saved;

    final projects = await client.getProjects();
    if (projects.isEmpty) {
      stderr.writeln(ConsoleStyle.error(
          'No projects found. Create one at https://ulink.ly first.'));
      return null;
    }
    if (projects.length == 1) return projects.first.id;

    stderr.writeln(ConsoleStyle.warning(
        'Multiple projects found — pass --project-id <id>:'));
    for (final p in projects) {
      stderr.writeln('  ${p.name}  ${ConsoleStyle.dim('(${p.id})')}');
    }
    return null;
  }

  /// First present, non-empty value among [keys] in [map], as a string.
  String? _field(Map<String, dynamic> map, List<String> keys) {
    for (final k in keys) {
      final v = map[k];
      if (v != null && v.toString().isNotEmpty) return v.toString();
    }
    return null;
  }

  void _printUsage() {
    stdout.writeln('Manage a project\'s ULink client SDK API keys.\n');
    stdout.writeln('Usage:');
    stdout.writeln('  ulink api-keys list    [--project-id <id>] [-p <dir>] [--json]');
    stdout.writeln('  ulink api-keys create  --name "<name>" [--project-id <id>] [-p <dir>] [--json]');
    stdout.writeln('  ulink api-keys revoke  <keyId> [--project-id <id>] [-p <dir>]\n');
    stdout.writeln('Notes:');
    stdout.writeln('  - Requires a signed-in user: run "ulink login" first.');
    stdout.writeln('  - The full key value is shown only once, when created.');
  }
}
