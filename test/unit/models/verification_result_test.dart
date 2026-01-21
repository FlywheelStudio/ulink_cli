import 'package:test/test.dart';
import 'package:ulink_cli/models/platform_config.dart';
import 'package:ulink_cli/models/verification_result.dart';

void main() {
  group('VerificationResult', () {
    test('should create result with all fields', () {
      final result = VerificationResult(
        checkName: 'Test Check',
        status: VerificationStatus.success,
        message: 'Test passed',
        fixSuggestion: 'No fix needed',
        details: {'key': 'value'},
      );

      expect(result.checkName, 'Test Check');
      expect(result.status, VerificationStatus.success);
      expect(result.message, 'Test passed');
      expect(result.fixSuggestion, 'No fix needed');
      expect(result.details?['key'], 'value');
    });

    test('should create result with required fields only', () {
      final result = VerificationResult(
        checkName: 'Test Check',
        status: VerificationStatus.error,
      );

      expect(result.checkName, 'Test Check');
      expect(result.status, VerificationStatus.error);
      expect(result.message, isNull);
      expect(result.fixSuggestion, isNull);
      expect(result.details, isNull);
    });
  });

  group('VerificationStatus', () {
    test('should have all expected values', () {
      expect(VerificationStatus.values, contains(VerificationStatus.success));
      expect(VerificationStatus.values, contains(VerificationStatus.warning));
      expect(VerificationStatus.values, contains(VerificationStatus.error));
      expect(VerificationStatus.values, contains(VerificationStatus.skipped));
    });
  });

  group('VerificationReport', () {
    test('should create report with results', () {
      final results = [
        VerificationResult(
          checkName: 'Check 1',
          status: VerificationStatus.success,
        ),
        VerificationResult(
          checkName: 'Check 2',
          status: VerificationStatus.warning,
        ),
        VerificationResult(
          checkName: 'Check 3',
          status: VerificationStatus.error,
        ),
      ];

      final report = VerificationReport(
        projectType: ProjectType.flutter,
        results: results,
      );

      expect(report.projectType, ProjectType.flutter);
      expect(report.results.length, 3);
      expect(report.timestamp, isNotNull);
    });

    test('should count success results', () {
      final results = [
        VerificationResult(
          checkName: 'Check 1',
          status: VerificationStatus.success,
        ),
        VerificationResult(
          checkName: 'Check 2',
          status: VerificationStatus.success,
        ),
        VerificationResult(
          checkName: 'Check 3',
          status: VerificationStatus.error,
        ),
      ];

      final report = VerificationReport(
        projectType: ProjectType.ios,
        results: results,
      );

      expect(report.successCount, 2);
    });

    test('should count warning results', () {
      final results = [
        VerificationResult(
          checkName: 'Check 1',
          status: VerificationStatus.warning,
        ),
        VerificationResult(
          checkName: 'Check 2',
          status: VerificationStatus.warning,
        ),
        VerificationResult(
          checkName: 'Check 3',
          status: VerificationStatus.warning,
        ),
        VerificationResult(
          checkName: 'Check 4',
          status: VerificationStatus.success,
        ),
      ];

      final report = VerificationReport(
        projectType: ProjectType.android,
        results: results,
      );

      expect(report.warningCount, 3);
    });

    test('should count error results', () {
      final results = [
        VerificationResult(
          checkName: 'Check 1',
          status: VerificationStatus.error,
        ),
        VerificationResult(
          checkName: 'Check 2',
          status: VerificationStatus.success,
        ),
      ];

      final report = VerificationReport(
        projectType: ProjectType.flutter,
        results: results,
      );

      expect(report.errorCount, 1);
    });

    test('should return hasErrors true when errors exist', () {
      final results = [
        VerificationResult(
          checkName: 'Check 1',
          status: VerificationStatus.error,
        ),
      ];

      final report = VerificationReport(
        projectType: ProjectType.flutter,
        results: results,
      );

      expect(report.hasErrors, isTrue);
    });

    test('should return hasErrors false when no errors', () {
      final results = [
        VerificationResult(
          checkName: 'Check 1',
          status: VerificationStatus.success,
        ),
        VerificationResult(
          checkName: 'Check 2',
          status: VerificationStatus.warning,
        ),
      ];

      final report = VerificationReport(
        projectType: ProjectType.flutter,
        results: results,
      );

      expect(report.hasErrors, isFalse);
    });

    test('should return hasWarnings true when warnings exist', () {
      final results = [
        VerificationResult(
          checkName: 'Check 1',
          status: VerificationStatus.warning,
        ),
      ];

      final report = VerificationReport(
        projectType: ProjectType.flutter,
        results: results,
      );

      expect(report.hasWarnings, isTrue);
    });

    test('should return hasWarnings false when no warnings', () {
      final results = [
        VerificationResult(
          checkName: 'Check 1',
          status: VerificationStatus.success,
        ),
      ];

      final report = VerificationReport(
        projectType: ProjectType.flutter,
        results: results,
      );

      expect(report.hasWarnings, isFalse);
    });

    test('should use provided timestamp', () {
      final timestamp = DateTime.utc(2024, 1, 1, 12, 0, 0);
      final report = VerificationReport(
        projectType: ProjectType.flutter,
        results: [],
        timestamp: timestamp,
      );

      expect(report.timestamp, timestamp);
    });

    test('should handle empty results', () {
      final report = VerificationReport(
        projectType: ProjectType.flutter,
        results: [],
      );

      expect(report.successCount, 0);
      expect(report.warningCount, 0);
      expect(report.errorCount, 0);
      expect(report.hasErrors, isFalse);
      expect(report.hasWarnings, isFalse);
    });
  });
}
