import 'dart:io';
import 'package:chalkdart/chalk.dart';

/// Utility class for styled console output with TTY detection
class ConsoleStyle {
  /// Check if colors should be enabled
  static bool get _colorsEnabled {
    // Respect NO_COLOR environment variable
    if (Platform.environment.containsKey('NO_COLOR')) {
      return false;
    }
    // Check if stdout is a TTY
    return stdout.hasTerminal;
  }

  /// Apply style only if colors are enabled
  static String _applyStyle(String text, String Function(String) styler) {
    if (_colorsEnabled) {
      return styler(text);
    }
    return text;
  }

  /// Red text for errors
  static String error(String text) {
    return _applyStyle(text, (t) => chalk.red(t));
  }

  /// Yellow text for warnings
  static String warning(String text) {
    return _applyStyle(text, (t) => chalk.yellow(t));
  }

  /// Green text for success
  static String success(String text) {
    return _applyStyle(text, (t) => chalk.green(t));
  }

  /// Cyan text for info
  static String info(String text) {
    return _applyStyle(text, (t) => chalk.cyan(t));
  }

  /// Bold text
  static String bold(String text) {
    return _applyStyle(text, (t) => chalk.bold(t));
  }

  /// Dimmed/gray text
  static String dim(String text) {
    return _applyStyle(text, (t) => chalk.gray(t));
  }

  /// Bold red for error headers
  static String errorBold(String text) {
    return _applyStyle(text, (t) => chalk.red.bold(t));
  }

  /// Bold yellow for warning headers
  static String warningBold(String text) {
    return _applyStyle(text, (t) => chalk.yellow.bold(t));
  }

  /// Bold green for success headers
  static String successBold(String text) {
    return _applyStyle(text, (t) => chalk.green.bold(t));
  }

  /// Bold cyan for info headers
  static String infoBold(String text) {
    return _applyStyle(text, (t) => chalk.cyan.bold(t));
  }
}
