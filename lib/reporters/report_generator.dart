import '../models/verification_result.dart';
import '../utils/console_style.dart';

/// Generator for verification reports
class ReportGenerator {
  /// Generate a formatted report
  ///
  /// [verbose] - If true, shows full detailed report with all checks.
  ///             If false (default), shows compact report with only errors/warnings.
  static String generateReport(VerificationReport report, {bool verbose = false}) {
    if (verbose) {
      return _generateVerboseReport(report);
    }
    return _generateSimpleReport(report);
  }

  /// Generate a compact, easy-to-read report (default mode)
  /// Shows only errors and warnings with fix suggestions
  static String _generateSimpleReport(VerificationReport report) {
    final buffer = StringBuffer();

    // Header with summary on one line
    buffer.writeln('');
    buffer.writeln(ConsoleStyle.infoBold('ULink Verification'));
    buffer.writeln(ConsoleStyle.dim('─' * 50));

    // Compact summary line
    final parts = <String>[];
    if (report.successCount > 0) {
      parts.add(ConsoleStyle.success('✓ ${report.successCount} passed'));
    }
    if (report.warningCount > 0) {
      parts.add(ConsoleStyle.warning('⚠ ${report.warningCount} warning${report.warningCount > 1 ? 's' : ''}'));
    }
    if (report.errorCount > 0) {
      parts.add(ConsoleStyle.error('✗ ${report.errorCount} error${report.errorCount > 1 ? 's' : ''}'));
    }
    buffer.writeln('${report.projectType.name} | ${parts.join('  ')}');
    buffer.writeln('');

    // Group results by status
    final errors = report.results
        .where((r) => r.status == VerificationStatus.error)
        .toList();
    final warnings = report.results
        .where((r) => r.status == VerificationStatus.warning)
        .toList();

    // Errors first (most important)
    if (errors.isNotEmpty) {
      buffer.writeln(ConsoleStyle.errorBold('✗ ERRORS:'));
      for (final result in errors) {
        buffer.writeln(ConsoleStyle.error('  ${result.checkName}'));
        if (result.message != null) {
          buffer.writeln(ConsoleStyle.dim('    ${result.message}'));
        }
        if (result.fixSuggestion != null) {
          buffer.writeln(ConsoleStyle.info('    → ${result.fixSuggestion}'));
        }
        buffer.writeln('');
      }
    }

    // Warnings
    if (warnings.isNotEmpty) {
      buffer.writeln(ConsoleStyle.warningBold('⚠ WARNINGS:'));
      for (final result in warnings) {
        buffer.writeln(ConsoleStyle.warning('  ${result.checkName}'));
        if (result.message != null) {
          buffer.writeln(ConsoleStyle.dim('    ${result.message}'));
        }
        if (result.fixSuggestion != null) {
          buffer.writeln(ConsoleStyle.info('    → ${result.fixSuggestion}'));
        }
        buffer.writeln('');
      }
    }

    // If no errors or warnings, show success message
    if (errors.isEmpty && warnings.isEmpty) {
      buffer.writeln(ConsoleStyle.success('All checks passed successfully!'));
      buffer.writeln('');
    }

    buffer.writeln(ConsoleStyle.dim('─' * 50));

    // Overall status
    if (report.hasErrors) {
      buffer.writeln(ConsoleStyle.errorBold('✗ FAILED - Fix ${report.errorCount} error${report.errorCount > 1 ? 's' : ''} above'));
    } else if (report.hasWarnings) {
      buffer.writeln(ConsoleStyle.warningBold('⚠ PASSED with ${report.warningCount} warning${report.warningCount > 1 ? 's' : ''}'));
    } else {
      buffer.writeln(ConsoleStyle.successBold('✓ PASSED'));
    }

    return buffer.toString();
  }

  /// Generate full detailed report (verbose mode)
  /// Shows all checks including successes and skipped
  static String _generateVerboseReport(VerificationReport report) {
    final buffer = StringBuffer();

    buffer.writeln(ConsoleStyle.dim('=' * 80));
    buffer.writeln(ConsoleStyle.infoBold('ULink Configuration Verification Report'));
    buffer.writeln(ConsoleStyle.dim('=' * 80));
    buffer.writeln('Project Type: ${report.projectType.name}');
    buffer.writeln(ConsoleStyle.dim('Timestamp: ${report.timestamp.toIso8601String()}'));
    buffer.writeln('');

    // Summary
    buffer.writeln(ConsoleStyle.bold('Summary:'));
    buffer.writeln(ConsoleStyle.success('  ✓ Success: ${report.successCount}'));
    buffer.writeln(ConsoleStyle.warning('  ⚠ Warnings: ${report.warningCount}'));
    buffer.writeln(ConsoleStyle.error('  ✗ Errors: ${report.errorCount}'));
    buffer.writeln('');

    // Group results by status
    final errors = report.results
        .where((r) => r.status == VerificationStatus.error)
        .toList();
    final warnings = report.results
        .where((r) => r.status == VerificationStatus.warning)
        .toList();
    final successes = report.results
        .where((r) => r.status == VerificationStatus.success)
        .toList();
    final skipped = report.results
        .where((r) => r.status == VerificationStatus.skipped)
        .toList();

    // Errors
    if (errors.isNotEmpty) {
      buffer.writeln(ConsoleStyle.errorBold('❌ ERRORS:'));
      buffer.writeln(ConsoleStyle.dim('-' * 80));
      for (final result in errors) {
        buffer.writeln(ConsoleStyle.error('  ${result.checkName}'));
        if (result.message != null) {
          buffer.writeln(ConsoleStyle.dim('    Message: ${result.message}'));
        }
        if (result.fixSuggestion != null) {
          buffer.writeln(ConsoleStyle.info('    Fix: ${result.fixSuggestion}'));
        }
        if (result.details != null) {
          buffer.writeln(ConsoleStyle.dim('    Details: ${result.details}'));
        }
        buffer.writeln('');
      }
    }

    // Warnings
    if (warnings.isNotEmpty) {
      buffer.writeln(ConsoleStyle.warningBold('⚠️  WARNINGS:'));
      buffer.writeln(ConsoleStyle.dim('-' * 80));
      for (final result in warnings) {
        buffer.writeln(ConsoleStyle.warning('  ${result.checkName}'));
        if (result.message != null) {
          buffer.writeln(ConsoleStyle.dim('    Message: ${result.message}'));
        }
        if (result.fixSuggestion != null) {
          buffer.writeln(ConsoleStyle.info('    Fix: ${result.fixSuggestion}'));
        }
        buffer.writeln('');
      }
    }

    // Successes
    if (successes.isNotEmpty) {
      buffer.writeln(ConsoleStyle.successBold('✓ SUCCESS:'));
      buffer.writeln(ConsoleStyle.dim('-' * 80));
      for (final result in successes) {
        buffer.writeln(ConsoleStyle.success('  ${result.checkName}'));
        if (result.message != null) {
          buffer.writeln(ConsoleStyle.dim('    ${result.message}'));
        }
        buffer.writeln('');
      }
    }

    // Skipped
    if (skipped.isNotEmpty) {
      buffer.writeln(ConsoleStyle.dim('⊘ SKIPPED:'));
      buffer.writeln(ConsoleStyle.dim('-' * 80));
      for (final result in skipped) {
        buffer.writeln(ConsoleStyle.dim('  ${result.checkName}'));
        if (result.message != null) {
          buffer.writeln(ConsoleStyle.dim('    ${result.message}'));
        }
        buffer.writeln('');
      }
    }

    buffer.writeln(ConsoleStyle.dim('=' * 80));

    // Overall status
    if (report.hasErrors) {
      buffer.writeln(ConsoleStyle.errorBold('❌ Verification FAILED - Please fix the errors above'));
    } else if (report.hasWarnings) {
      buffer.writeln(ConsoleStyle.warningBold('⚠️  Verification completed with WARNINGS'));
    } else {
      buffer.writeln(ConsoleStyle.successBold('✓ Verification PASSED'));
    }

    return buffer.toString();
  }

  /// Generate a JSON report
  static Map<String, dynamic> generateJsonReport(VerificationReport report) {
    return {
      'projectType': report.projectType.name,
      'timestamp': report.timestamp.toIso8601String(),
      'summary': {
        'success': report.successCount,
        'warnings': report.warningCount,
        'errors': report.errorCount,
      },
      'results': report.results
          .map(
            (r) => {
              'checkName': r.checkName,
              'status': r.status.name,
              'message': r.message,
              'fixSuggestion': r.fixSuggestion,
              'details': r.details,
            },
          )
          .toList(),
    };
  }
}
