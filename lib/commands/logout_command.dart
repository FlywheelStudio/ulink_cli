import 'dart:io';
import '../auth/config_manager.dart';

/// Command for logging out of ULink
class LogoutCommand {
  /// Execute logout
  Future<void> execute() async {
    try {
      await ConfigManager.clearConfig();
      print('✓ Successfully logged out');
    } catch (e) {
      stderr.writeln('Logout failed: $e');
      exit(1);
    }
  }
}
