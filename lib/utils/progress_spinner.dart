import 'dart:io';
import 'package:cli_spin/cli_spin.dart';
import 'console_style.dart';

/// Wrapper for progress spinners with TTY detection
class ProgressSpinner {
  final String message;
  final bool verbose;
  CliSpin? _spinner;
  bool _isSpinnerMode = false;

  ProgressSpinner(this.message, {this.verbose = false});

  /// Check if spinners should be enabled
  static bool get _spinnersEnabled {
    // Disable spinners if not a TTY (CI/CD, piped output)
    return stdout.hasTerminal;
  }

  /// Start the spinner
  void start() {
    if (verbose) {
      // In verbose mode, just print text instead of spinners
      print('$message');
      return;
    }

    if (_spinnersEnabled) {
      _isSpinnerMode = true;
      _spinner = CliSpin(
        text: message,
        spinner: CliSpinners.dots,
      );
      _spinner!.start();
    } else {
      // Non-TTY: just print the message
      print(message);
    }
  }

  /// Stop with success status
  void success(String msg) {
    if (verbose) {
      print(ConsoleStyle.success('✓ $msg'));
      return;
    }

    if (_isSpinnerMode && _spinner != null) {
      _spinner!.success(ConsoleStyle.success('✓ $msg'));
    } else if (!_isSpinnerMode) {
      print('✓ $msg');
    }
  }

  /// Stop with failure status
  void fail(String msg) {
    if (verbose) {
      print(ConsoleStyle.error('✗ $msg'));
      return;
    }

    if (_isSpinnerMode && _spinner != null) {
      _spinner!.fail(ConsoleStyle.error('✗ $msg'));
    } else if (!_isSpinnerMode) {
      print('✗ $msg');
    }
  }

  /// Stop with warning status
  void warn(String msg) {
    if (verbose) {
      print(ConsoleStyle.warning('⚠ $msg'));
      return;
    }

    if (_isSpinnerMode && _spinner != null) {
      _spinner!.warn(ConsoleStyle.warning('⚠ $msg'));
    } else if (!_isSpinnerMode) {
      print('⚠ $msg');
    }
  }

  /// Stop spinner without changing message (for custom handling)
  void stop() {
    if (_isSpinnerMode && _spinner != null) {
      _spinner!.stop();
    }
  }

  /// Update the spinner text
  void update(String newMessage) {
    if (verbose) {
      return; // Don't update in verbose mode
    }

    if (_isSpinnerMode && _spinner != null) {
      _spinner!.text = newMessage;
    }
  }
}
