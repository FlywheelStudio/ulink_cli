import 'platform_config.dart';

export 'verification_result.dart' show VerificationReport;

/// Result of a verification check
class VerificationResult {
  final String checkName;
  final VerificationStatus status;
  final String? message;
  final String? fixSuggestion;
  final Map<String, dynamic>? details;

  VerificationResult({
    required this.checkName,
    required this.status,
    this.message,
    this.fixSuggestion,
    this.details,
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

  bool get hasErrors => errorCount > 0;
  bool get hasWarnings => warningCount > 0;
}
