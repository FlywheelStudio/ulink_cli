#!/usr/bin/env dart

import 'dart:io';
import 'package:args/args.dart';
import 'package:ulink_cli/ulink_cli.dart';
import 'package:ulink_cli/config/version.dart';
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
        ..addOption('path', abbr: 'p', defaultsTo: '.', help: 'Project path'),
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
    print('  verify    Verify project configuration');
    print('  fix       Interactive mode to fix configuration issues');
    print('  login     Authenticate with ULink (browser, email/password, or API key)');
    print('  logout    Clear stored credentials');
    print('  project   Manage project selection for current directory');
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
      final projectPath = results.command!['path'] as String;
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
