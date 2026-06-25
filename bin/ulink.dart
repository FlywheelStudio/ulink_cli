#!/usr/bin/env dart

import 'dart:io';
import 'package:args/args.dart';
import 'package:ulink_cli/ulink_cli.dart';
import 'package:ulink_cli/utils/update_checker.dart';

void main(List<String> args) async {
  final parser = ArgParser()
    ..addFlag(
      'interactive',
      abbr: 'i',
      help: 'Interactive mode for fixing issues',
    )
    ..addFlag('verbose', abbr: 'v', help: 'Verbose output')
    ..addFlag('version',
        abbr: 'V', negatable: false, help: 'Show version information')
    ..addFlag('help',
        abbr: 'h', negatable: false, help: 'Show this help message')
    ..addOption('api-url',
        help: 'Override API base URL (for development)',
        valueHelp: 'URL')
    ..addCommand(
      'verify',
      ArgParser()
        ..addOption('path', abbr: 'p', defaultsTo: '.', help: 'Project path')
        // Standalone domain-verify mode (no project / no login): pass a domain
        // as the first argument or via --domain to check the public AASA +
        // assetlinks.json association files directly.
        ..addOption('domain',
            abbr: 'd', help: 'Domain to verify its app-link association files')
        ..addOption('ios', help: 'Assert this iOS App ID (TEAMID.bundleId)')
        ..addOption('android',
            help: 'Assert this Android app (package[:SHA256FP])')
        ..addFlag('json',
            negatable: false,
            help: 'Print the machine-readable domain-verify result to stdout')
        ..addFlag('help', abbr: 'h', negatable: false),
    )
    ..addCommand(
      'fix',
      ArgParser()
        ..addOption('path', abbr: 'p', defaultsTo: '.', help: 'Project path'),
    )
    ..addCommand(
      'login',
      ArgParser()
        ..addFlag('api-key',
            help: 'Login with API key instead of browser')
        ..addFlag('password',
            abbr: 'p',
            help: 'Login with email/password instead of browser'),
    )
    ..addCommand('logout', ArgParser())
    ..addCommand('version', ArgParser())
    ..addCommand(
      'resolve',
      ArgParser()
        ..addOption('url',
            help: 'The ULink short URL (or pass it as the first argument)')
        ..addOption('api-key',
            help: 'ULink API key (or set ULINK_API_KEY); optional')
        ..addFlag('json',
            negatable: false,
            help: 'Print the machine-readable resolution to stdout')
        ..addFlag('help', abbr: 'h', negatable: false),
    )
    ..addCommand(
      'import',
      ArgParser()
        ..addCommand(
          'firebase',
          ArgParser()
            ..addOption('input',
                abbr: 'i', help: 'Path to your FDL export ("-" for stdin)')
            ..addOption('domain',
                abbr: 'd', help: 'Your ULink domain for the new links')
            ..addOption('out',
                abbr: 'o', help: 'Output dir for manifest + link JSON')
            ..addOption('api-key', help: 'ULink API key for --live')
            ..addFlag('dry-run',
                negatable: false,
                help: 'Preview only; never calls the ULink API (default)')
            ..addFlag('live',
                negatable: false, help: 'Create links via the ULink API')
            ..addFlag('verify',
                defaultsTo: true, help: 'Run routing+attribution parity checks')
            ..addFlag('json',
                negatable: false, help: 'Print the manifest as JSON to stdout')
            ..addFlag('help', abbr: 'h', negatable: false),
        ),
    )
    ..addCommand(
      'project',
      ArgParser()
        ..addCommand(
            'set',
            ArgParser()
              ..addOption('path',
                  abbr: 'p', defaultsTo: '.', help: 'Project path')
              ..addOption('slug',
                  abbr: 's', help: 'Project slug to set directly'))
        ..addCommand(
            'show',
            ArgParser()
              ..addOption('path',
                  abbr: 'p', defaultsTo: '.', help: 'Project path')),
    );

  // Check for version flag before parsing (to handle --version at root level)
  if (args.contains('--version') || args.contains('-V')) {
    print(ULinkVersion.versionInfo);
    exit(0);
  }

  final results = parser.parse(args);

  // Check for updates (non-blocking, once per day)
  // Fire and forget - don't await, let it run in background
  UpdateChecker.checkForUpdates().ignore();

  // Show cached update message if available (fast, sync check)
  UpdateChecker.showCachedUpdateMessage();

  if ((results['help'] as bool? ?? false) || results.command == null) {
    print('ULink CLI - Universal Links and App Links Verification Tool');
    print('Version: ${ULinkVersion.shortVersion}\n');
    print('Usage: ulink <command> [options]\n');
    print('Commands:');
    print('  verify    Verify project configuration (or a domain: verify <domain>)');
    print('  fix       Interactive mode to fix configuration issues');
    print('  login     Authenticate with ULink (browser, email/password, or API key)');
    print('  logout    Clear stored credentials');
    print('  project   Manage project selection for current directory');
    print('  import    Migrate Firebase Dynamic Links to ULink (import firebase)');
    print('  resolve   Show where a ULink short URL resolves per platform');
    print('  version   Show version information\n');
    print('Options:');
    print(parser.usage);
    exit(0);
  }

  // Allow API URL override via flag or environment variable
  final baseUrl = results['api-url'] as String? ??
      Platform.environment['ULINK_API_URL'] ??
      'https://api.ulink.ly';

  final cli = ULinkCLI(
    baseUrl: baseUrl,
    verbose: results['verbose'] as bool,
    interactive: results['interactive'] as bool,
  );

  try {
    if (results.command!.name == 'verify') {
      final sub = results.command!;
      // A domain (positional or --domain) selects standalone domain-verify;
      // otherwise fall through to project-config verify. Project mode never
      // takes a positional (it uses -p/--path), so there is no ambiguity.
      final domainArg =
          (sub['domain'] as String?) ?? (sub.rest.isNotEmpty ? sub.rest.first : null);
      final help = sub['help'] as bool? ?? false;
      if (domainArg != null || help) {
        final command = DomainVerifyCommand();
        final result = await command.run(DomainVerifyOptions(
          domain: domainArg,
          ios: sub['ios'] as String?,
          android: sub['android'] as String?,
          json: sub['json'] as bool? ?? false,
          help: help,
        ));
        exit(result.exitCode);
      }
      final projectPath = sub['path'] as String;
      await cli.verify(projectPath);
    } else if (results.command!.name == 'fix') {
      final projectPath = results.command!['path'] as String;
      await cli.fix(projectPath);
    } else if (results.command!.name == 'login') {
      final useApiKey = results.command!['api-key'] as bool? ?? false;
      final usePassword = results.command!['password'] as bool? ?? false;
      await cli.login(useApiKey: useApiKey, usePassword: usePassword);
    } else if (results.command!.name == 'logout') {
      await cli.logout();
    } else if (results.command!.name == 'import') {
      final sub = results.command!.command;
      if (sub == null || sub.name != 'firebase') {
        stderr.writeln(
            'Usage: ulink import firebase --input <export> --domain <domain> [options]');
        stderr.writeln('  See `ulink import firebase --help` for details.');
        exit(2);
      }
      final opts = ImportOptions(
        input: sub['input'] as String?,
        domain: sub['domain'] as String?,
        out: sub['out'] as String?,
        live: sub['live'] as bool? ?? false,
        verify: sub['verify'] as bool? ?? true,
        json: sub['json'] as bool? ?? false,
        help: sub['help'] as bool? ?? false,
        apiKey: sub['api-key'] as String?,
      );
      final command =
          ImportCommand(client: SdkLinksClient(apiBase: baseUrl));
      final result = await command.runFirebase(opts);
      exit(result.exitCode);
    } else if (results.command!.name == 'resolve') {
      final sub = results.command!;
      // Accept the short URL as a positional arg or via --url.
      final positional = sub.rest.isNotEmpty ? sub.rest.first : null;
      final opts = ResolveOptions(
        url: (sub['url'] as String?) ?? positional,
        apiKey: sub['api-key'] as String?,
        json: sub['json'] as bool? ?? false,
        help: sub['help'] as bool? ?? false,
      );
      final command = ResolveCommand(client: SdkLinksClient(apiBase: baseUrl));
      final result = await command.run(opts);
      exit(result.exitCode);
    } else if (results.command!.name == 'version') {
      print(ULinkVersion.versionInfo);
      exit(0);
    } else if (results.command!.name == 'project') {
      final subcommand = results.command!.command;
      if (subcommand == null) {
        stderr.writeln('Usage: ulink project <set|show>');
        stderr.writeln('  set   - Set project for current directory');
        stderr.writeln('  show  - Show current project for directory');
        exit(1);
      }

      final projectPath = subcommand['path'] as String? ?? '.';
      final projectSlug = subcommand['slug'] as String?;

      if (subcommand.name == 'set') {
        await cli.setProject(path: projectPath, slug: projectSlug);
      } else if (subcommand.name == 'show') {
        await cli.showProject(path: projectPath);
      } else {
        stderr.writeln('Usage: ulink project <set|show>');
        exit(1);
      }
    }
  } catch (e, stackTrace) {
    stderr.writeln('Error: $e');
    if (results['verbose'] as bool) {
      stderr.writeln(stackTrace);
    }
    exit(1);
  }
}
