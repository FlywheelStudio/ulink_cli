import 'dart:io';
import '../api/ulink_api_client.dart';
import '../auth/config_manager.dart';
import '../models/auth_config.dart';
import '../config/project_config_manager.dart';
import 'package:path/path.dart' as path;

/// Command for managing project selection
class ProjectCommand {
  final String baseUrl;
  final bool verbose;

  ProjectCommand({
    required this.baseUrl,
    this.verbose = false,
  });

  /// Set project for current directory
  Future<void> setProject(String? projectPath, {String? slug}) async {
    final absolutePath = (projectPath != null && projectPath != '.')
        ? path.absolute(projectPath)
        : Directory.current.path;

    print('🔧 Setting project for: $absolutePath\n');

    // Check if user is logged in
    final config = ConfigManager.loadConfig();
    final hasCredentials = config?.auth?.type == AuthType.apiKey ||
        (config?.auth?.type == AuthType.jwt && config!.auth!.token != null);

    if (!hasCredentials) {
      stderr.writeln('Error: Not logged in. Please run "ulink login" first.');
      exit(1);
    }

    try {
      final apiClient = ULinkApiClient(baseUrl: baseUrl);

      // If slug is provided, fetch project by slug directly
      if (slug != null) {
        print('📋 Fetching project by slug: $slug...');
        final project = await apiClient.getProjectBySlug(slug);

        // Save to directory config
        await ProjectConfigManager.saveProjectId(
          absolutePath,
          project.id,
          projectName: project.name,
        );
        print('\n✓ Project set successfully!');
        print('  Project: ${project.name}');
        print('  Project ID: ${project.id}');
        print('  Slug: ${project.slug ?? slug}');
        print(
            '  Config saved to: ${path.join(absolutePath, '.ulink', 'project.json')}');
        return;
      }

      // Interactive mode: fetch available projects
      print('📋 Fetching your projects...');
      final projects = await apiClient.getProjects();

      if (projects.isEmpty) {
        stderr.writeln(
            'No projects found. Create a project in the ULink dashboard first.');
        stderr.writeln('Visit https://ulink.ly to create a project');
        exit(1);
      }

      // Show current project if exists
      final currentProjectId = ProjectConfigManager.loadProjectId(absolutePath);
      if (currentProjectId != null) {
        final currentProject = projects.firstWhere(
          (p) => p.id == currentProjectId,
          orElse: () => projects.first,
        );
        print(
            'Current project: ${currentProject.name} (${currentProject.id})\n');
      }

      // Show selection menu
      print('📁 Select a project:');
      for (int i = 0; i < projects.length; i++) {
        final marker = projects[i].id == currentProjectId ? '← current' : '';
        final slugInfo = projects[i].slug != null ? ' [${projects[i].slug}]' : '';
        print('  ${i + 1}. ${projects[i].name}$slugInfo $marker');
      }

      stdout.write('\nEnter project number (1-${projects.length}): ');
      final input = stdin.readLineSync()?.trim();
      final selectedIndex = int.tryParse(input ?? '') ?? 0;

      if (selectedIndex < 1 || selectedIndex > projects.length) {
        stderr.writeln(
            'Error: Invalid selection. Please enter a number between 1 and ${projects.length}.');
        exit(1);
      }

      final selectedProject = projects[selectedIndex - 1];

      // Save to directory config
      try {
        await ProjectConfigManager.saveProjectId(
          absolutePath,
          selectedProject.id,
          projectName: selectedProject.name,
        );
        print('\n✓ Project set successfully!');
        print('  Project: ${selectedProject.name}');
        print('  Project ID: ${selectedProject.id}');
        if (selectedProject.slug != null) {
          print('  Slug: ${selectedProject.slug}');
        }
        print(
            '  Config saved to: ${path.join(absolutePath, '.ulink', 'project.json')}');
      } catch (e) {
        stderr.writeln('\n✗ Failed to save project configuration: $e');
        exit(1);
      }
    } catch (e) {
      stderr.writeln('Error: Failed to set project: $e');
      if (verbose) {
        stderr.writeln(e.toString());
      }
      exit(1);
    }
  }

  /// Show current project for directory
  Future<void> showCurrent(String? projectPath) async {
    final absolutePath = (projectPath != null && projectPath != '.')
        ? path.absolute(projectPath)
        : Directory.current.path;

    final projectId = ProjectConfigManager.loadProjectId(absolutePath);
    final config = ConfigManager.loadConfig();

    print('📁 Directory: $absolutePath');
    print('');

    if (projectId != null) {
      print('✓ Project set for this directory:');
      print('  Project ID: $projectId');
      print(
          '  Config file: ${path.join(absolutePath, '.ulink', 'project.json')}');

      // Try to get project name from API if available
      if (config?.auth != null) {
        try {
          final apiClient = ULinkApiClient(
            baseUrl: baseUrl,
            apiKey: config!.auth!.apiKey,
          );
          final projects = await apiClient.getProjects();
          final project = projects.firstWhere(
            (p) => p.id == projectId,
            orElse: () => projects.first,
          );
          print('  Project Name: ${project.name}');
        } catch (e) {
          // Ignore errors when fetching project name
        }
      }
    } else {
      print('✗ No project set for this directory');
      print('  Run "ulink project set" to select a project for this directory');
    }
  }
}
