import 'platform_config.dart';

export 'verification_result.dart' show VerificationReport;

/// Result of a verification check
class VerificationResult {
  final String checkName;
  final VerificationStatus status;
  final String? message;
  final String? fixSuggestion;
  final Map<String, dynamic>? details;

  /// For a [VerificationStatus.skipped] result: whether this skip means the run
  /// is not a full verification. `true` only for checks that would actually
  /// verify something and were not performed — chiefly the dashboard
  /// cross-check (comparing local config against the ULink project and fetching
  /// the hosted AASA / assetlinks.json). Optional environment probes that simply
  /// could not run (no booted simulator, no `adb`, a managed-Expo project with
  /// no native dirs) leave this `false`: they never downgrade the verdict.
  final bool blocksFullVerification;

  VerificationResult({
    required this.checkName,
    required this.status,
    this.message,
    this.fixSuggestion,
    this.details,
    this.blocksFullVerification = false,
  });
}

/// Verification status
enum VerificationStatus { success, warning, error, skipped }

/// Complete verification report
class VerificationReport {
  final ProjectType projectType;
  final List<VerificationResult> results;
  final DateTime timestamp;

  VerificationReport({
    required this.projectType,
    required this.results,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  int get successCount =>
      results.where((r) => r.status == VerificationStatus.success).length;
  int get warningCount =>
      results.where((r) => r.status == VerificationStatus.warning).length;
  int get errorCount =>
      results.where((r) => r.status == VerificationStatus.error).length;
  int get skippedCount =>
      results.where((r) => r.status == VerificationStatus.skipped).length;

  /// Skips that mean the run is not a full verification (e.g. the dashboard
  /// cross-check was not performed) — as opposed to optional probes that merely
  /// could not run.
  int get incompleteCount => results
      .where((r) =>
          r.status == VerificationStatus.skipped && r.blocksFullVerification)
      .length;

  /// Skips that do not affect the verdict (no simulator, no `adb`, managed-Expo
  /// with no native dirs).
  int get optionalSkippedCount => skippedCount - incompleteCount;

  bool get hasErrors => errorCount > 0;
  bool get hasWarnings => warningCount > 0;
  bool get hasSkipped => skippedCount > 0;

  /// True when at least one skipped check would actually verify something and
  /// was not performed — i.e. the run is only a partial verification. Optional
  /// probe skips alone do not make a run partial.
  bool get isPartial => incompleteCount > 0;
}
