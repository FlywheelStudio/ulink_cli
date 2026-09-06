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
    if (report.skippedCount > 0) {
      parts.add(ConsoleStyle.dim('⊘ ${report.skippedCount} skipped'));
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
    final skipped = report.results
        .where((r) => r.status == VerificationStatus.skipped)
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

    // Blocking skips: a check that would actually verify deep linking (chiefly
    // the dashboard cross-check — comparing local config against the ULink
    // project and fetching the hosted AASA / assetlinks.json) was NOT performed,
    // so the run is only a partial verification.
    final notVerified = skipped.where((r) => r.blocksFullVerification).toList();
    // Optional probes that simply could not run in this environment (no booted
    // simulator, no `adb`, managed-Expo with no native dirs). These do NOT
    // downgrade the verdict.
    final optionalSkipped =
        skipped.where((r) => !r.blocksFullVerification).toList();

    if (notVerified.isNotEmpty) {
      buffer.writeln(ConsoleStyle.dim('⊘ NOT VERIFIED:'));
      for (final result in notVerified) {
        buffer.writeln(ConsoleStyle.dim('  ${result.checkName}'));
        if (result.message != null) {
          buffer.writeln(ConsoleStyle.dim('    ${result.message}'));
        }
        if (result.fixSuggestion != null) {
          buffer.writeln(ConsoleStyle.info('    → ${result.fixSuggestion}'));
        }
        buffer.writeln('');
      }
    }

    if (optionalSkipped.isNotEmpty) {
      buffer.writeln(
          ConsoleStyle.dim('⊘ SKIPPED (optional — did not affect the result):'));
      for (final result in optionalSkipped) {
        buffer.writeln(ConsoleStyle.dim('  ${result.checkName}'));
        if (result.message != null) {
          buffer.writeln(ConsoleStyle.dim('    ${result.message}'));
        }
        buffer.writeln('');
      }
    }

    // If no errors or warnings, show success message
    if (errors.isEmpty && warnings.isEmpty && skipped.isEmpty) {
      buffer.writeln(ConsoleStyle.success('All checks passed successfully!'));
      buffer.writeln('');
    }

    buffer.writeln(ConsoleStyle.dim('─' * 50));

    // Overall status. A clean "✓ PASSED" is reserved for a full run — one where
    // no check that would actually verify deep linking was skipped. A skipped
    // dashboard cross-check downgrades to PARTIAL; optional probes that could
    // not run (no simulator/adb) are noted but never change the verdict.
    final optionalNote = report.optionalSkippedCount > 0
        ? ' (${report.optionalSkippedCount} optional check${report.optionalSkippedCount > 1 ? 's' : ''} skipped)'
        : '';
    if (report.hasErrors) {
      buffer.writeln(ConsoleStyle.errorBold('✗ FAILED - Fix ${report.errorCount} error${report.errorCount > 1 ? 's' : ''} above'));
    } else if (report.isPartial) {
      final warnSuffix = report.hasWarnings
          ? ' and ${report.warningCount} warning${report.warningCount > 1 ? 's' : ''}'
          : '';
      buffer.writeln(ConsoleStyle.warningBold(
          '⚠ PARTIAL - local checks passed, but ${report.incompleteCount} check${report.incompleteCount > 1 ? 's were' : ' was'} not verified$warnSuffix (see above). This is NOT a full verification.'));
    } else if (report.hasWarnings) {
      buffer.writeln(ConsoleStyle.warningBold('⚠ PASSED with ${report.warningCount} warning${report.warningCount > 1 ? 's' : ''}$optionalNote'));
    } else {
      buffer.writeln(ConsoleStyle.successBold('✓ PASSED$optionalNote'));
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
    } else if (report.isPartial) {
      buffer.writeln(ConsoleStyle.warningBold(
          '⚠️  Verification PARTIAL - ${report.incompleteCount} check${report.incompleteCount > 1 ? 's were' : ' was'} not verified (see above). This is NOT a full verification.'));
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
        'skipped': report.skippedCount,
        // Skips that make the run a partial verification (a subset of skipped).
        'incomplete': report.incompleteCount,
      },
      'partial': report.isPartial,
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
