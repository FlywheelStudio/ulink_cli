library ulink_cli;

export 'commands/verify_command.dart';
export 'commands/fix_command.dart';
export 'commands/login_command.dart';
export 'commands/logout_command.dart';
export 'commands/project_command.dart';
export 'auth/config_manager.dart';
export 'auth/auth_service.dart';
export 'models/auth_config.dart';
export 'models/project_config.dart';
export 'models/verification_result.dart';
export 'models/platform_config.dart';
export 'parsers/ios_parser.dart';
export 'parsers/android_parser.dart';
export 'parsers/flutter_parser.dart';
export 'parsers/gradle_parser.dart';
export 'parsers/podfile_parser.dart';
export 'parsers/package_swift_parser.dart';
export 'parsers/project_detector.dart';
export 'validators/sdk_package_validator.dart';
export 'validators/ios_validator.dart';
export 'validators/android_validator.dart';
export 'validators/config_validator.dart';
export 'api/ulink_api_client.dart';
export 'testers/well_known_tester.dart';
export 'testers/ios_runtime_tester.dart';
export 'testers/android_runtime_tester.dart';
export 'reporters/report_generator.dart';
export 'config/version.dart';
export 'auth/browser_auth_service.dart';
export 'auth/local_auth_server.dart';

import 'commands/verify_command.dart';
import 'commands/fix_command.dart';
import 'commands/login_command.dart';
import 'commands/logout_command.dart';
import 'commands/project_command.dart';

/// Main CLI class for ULink verification tool
class ULinkCLI {
  final String baseUrl;
  final bool verbose;
  final bool interactive;

  ULinkCLI({
    required this.baseUrl,
    this.verbose = false,
    this.interactive = false,
  });

  /// Verify project configuration
  Future<void> verify(String projectPath) async {
    final verifyCommand = VerifyCommand(
      baseUrl: baseUrl,
      verbose: verbose,
    );
    await verifyCommand.execute(projectPath);
  }

  /// Fix configuration issues interactively
  Future<void> fix(String projectPath) async {
    final fixCommand = FixCommand(
      baseUrl: baseUrl,
      verbose: verbose,
    );
    await fixCommand.execute(projectPath);
  }

  /// Login to ULink
  Future<void> login({bool useApiKey = false, bool usePassword = false}) async {
    final loginCommand = LoginCommand(verbose: verbose, baseUrl: baseUrl);
    await loginCommand.execute(useApiKey: useApiKey, usePassword: usePassword);
  }

  /// Logout from ULink
  Future<void> logout() async {
    final logoutCommand = LogoutCommand();
    await logoutCommand.execute();
  }

  /// Set project for current directory
  Future<void> setProject({String? path, String? slug}) async {
    final projectCommand = ProjectCommand(baseUrl: baseUrl, verbose: verbose);
    await projectCommand.setProject(path, slug: slug);
  }

  /// Show current project for directory
  Future<void> showProject({String? path}) async {
    final projectCommand = ProjectCommand(baseUrl: baseUrl, verbose: verbose);
    await projectCommand.showCurrent(path);
  }
}
