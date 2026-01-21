import 'package:test/test.dart';
import 'package:ulink_cli/models/platform_config.dart';
import 'package:ulink_cli/models/verification_result.dart';
import 'package:ulink_cli/reporters/report_generator.dart';

void main() {
  group('ReportGenerator', () {
    group('generateReport', () {
      test('should generate simple report by default', () {
        final report = VerificationReport(
          projectType: ProjectType.flutter,
          results: [
            VerificationResult(
              checkName: 'Test Check',
              status: VerificationStatus.success,
              message: 'Success message',
            ),
          ],
        );

        final result = ReportGenerator.generateReport(report);

        expect(result, contains('ULink Verification'));
        expect(result, contains('flutter'));
        expect(result, contains('passed'));
      });

      test('should generate verbose report when requested', () {
        final report = VerificationReport(
          projectType: ProjectType.flutter,
          results: [
            VerificationResult(
              checkName: 'Test Check',
              status: VerificationStatus.success,
              message: 'Success message',
            ),
          ],
        );

        final result = ReportGenerator.generateReport(report, verbose: true);

        expect(result, contains('ULink Configuration Verification Report'));
        expect(result, contains('Summary'));
        expect(result, contains('SUCCESS'));
      });

      test('should include errors in report', () {
        final report = VerificationReport(
          projectType: ProjectType.ios,
          results: [
            VerificationResult(
              checkName: 'Error Check',
              status: VerificationStatus.error,
              message: 'Something went wrong',
              fixSuggestion: 'Fix this way',
            ),
          ],
        );

        final result = ReportGenerator.generateReport(report);

        expect(result, contains('ERRORS'));
        expect(result, contains('Error Check'));
        expect(result, contains('Something went wrong'));
        expect(result, contains('Fix this way'));
        expect(result, contains('FAILED'));
      });

      test('should include warnings in report', () {
        final report = VerificationReport(
          projectType: ProjectType.android,
          results: [
            VerificationResult(
              checkName: 'Warning Check',
              status: VerificationStatus.warning,
              message: 'Consider this',
            ),
          ],
        );

        final result = ReportGenerator.generateReport(report);

        expect(result, contains('WARNINGS'));
        expect(result, contains('Warning Check'));
        expect(result, contains('Consider this'));
        expect(result, contains('PASSED with'));
      });

      test('should show all passed message when no errors or warnings', () {
        final report = VerificationReport(
          projectType: ProjectType.flutter,
          results: [
            VerificationResult(
              checkName: 'Check 1',
              status: VerificationStatus.success,
            ),
            VerificationResult(
              checkName: 'Check 2',
              status: VerificationStatus.success,
            ),
          ],
        );

        final result = ReportGenerator.generateReport(report);

        expect(result, contains('All checks passed'));
        expect(result, contains('PASSED'));
      });

      test('should handle empty results', () {
        final report = VerificationReport(
          projectType: ProjectType.flutter,
          results: [],
        );

        final result = ReportGenerator.generateReport(report);

        expect(result, contains('ULink Verification'));
        expect(result, contains('All checks passed'));
      });
    });

    group('generateReport verbose', () {
      test('should include timestamp in verbose report', () {
        final timestamp = DateTime.utc(2024, 1, 15, 12, 30, 0);
        final report = VerificationReport(
          projectType: ProjectType.flutter,
          results: [],
          timestamp: timestamp,
        );

        final result = ReportGenerator.generateReport(report, verbose: true);

        expect(result, contains('2024-01-15'));
      });

      test('should show success section in verbose report', () {
        final report = VerificationReport(
          projectType: ProjectType.flutter,
          results: [
            VerificationResult(
              checkName: 'Success Check',
              status: VerificationStatus.success,
              message: 'It worked',
            ),
          ],
        );

        final result = ReportGenerator.generateReport(report, verbose: true);

        expect(result, contains('SUCCESS'));
        expect(result, contains('Success Check'));
        expect(result, contains('It worked'));
      });

      test('should show skipped section in verbose report', () {
        final report = VerificationReport(
          projectType: ProjectType.flutter,
          results: [
            VerificationResult(
              checkName: 'Skipped Check',
              status: VerificationStatus.skipped,
              message: 'Not applicable',
            ),
          ],
        );

        final result = ReportGenerator.generateReport(report, verbose: true);

        expect(result, contains('SKIPPED'));
        expect(result, contains('Skipped Check'));
      });

      test('should show details in verbose error report', () {
        final report = VerificationReport(
          projectType: ProjectType.flutter,
          results: [
            VerificationResult(
              checkName: 'Error Check',
              status: VerificationStatus.error,
              message: 'Error message',
              fixSuggestion: 'Fix suggestion',
              details: {'key': 'value'},
            ),
          ],
        );

        final result = ReportGenerator.generateReport(report, verbose: true);

        expect(result, contains('Details:'));
        expect(result, contains('key'));
      });
    });

    group('generateJsonReport', () {
      test('should generate valid JSON structure', () {
        final timestamp = DateTime.utc(2024, 1, 15, 12, 30, 0);
        final report = VerificationReport(
          projectType: ProjectType.flutter,
          results: [
            VerificationResult(
              checkName: 'Check 1',
              status: VerificationStatus.success,
              message: 'Success',
            ),
            VerificationResult(
              checkName: 'Check 2',
              status: VerificationStatus.error,
              message: 'Error',
              fixSuggestion: 'Fix it',
            ),
          ],
          timestamp: timestamp,
        );

        final json = ReportGenerator.generateJsonReport(report);

        expect(json['projectType'], 'flutter');
        expect(json['timestamp'], '2024-01-15T12:30:00.000Z');
        expect(json['summary']['success'], 1);
        expect(json['summary']['warnings'], 0);
        expect(json['summary']['errors'], 1);
        expect(json['results'], isList);
        expect(json['results'].length, 2);
      });

      test('should include all result fields in JSON', () {
        final report = VerificationReport(
          projectType: ProjectType.ios,
          results: [
            VerificationResult(
              checkName: 'Test Check',
              status: VerificationStatus.warning,
              message: 'Warning message',
              fixSuggestion: 'Fix suggestion',
              details: {'foo': 'bar'},
            ),
          ],
        );

        final json = ReportGenerator.generateJsonReport(report);
        final resultJson = json['results'][0] as Map<String, dynamic>;

        expect(resultJson['checkName'], 'Test Check');
        expect(resultJson['status'], 'warning');
        expect(resultJson['message'], 'Warning message');
        expect(resultJson['fixSuggestion'], 'Fix suggestion');
        expect(resultJson['details']['foo'], 'bar');
      });

      test('should handle null optional fields in JSON', () {
        final report = VerificationReport(
          projectType: ProjectType.android,
          results: [
            VerificationResult(
              checkName: 'Simple Check',
              status: VerificationStatus.success,
            ),
          ],
        );

        final json = ReportGenerator.generateJsonReport(report);
        final resultJson = json['results'][0] as Map<String, dynamic>;

        expect(resultJson['checkName'], 'Simple Check');
        expect(resultJson['status'], 'success');
        expect(resultJson['message'], isNull);
        expect(resultJson['fixSuggestion'], isNull);
        expect(resultJson['details'], isNull);
      });

      test('should handle empty results in JSON', () {
        final report = VerificationReport(
          projectType: ProjectType.flutter,
          results: [],
        );

        final json = ReportGenerator.generateJsonReport(report);

        expect(json['results'], isEmpty);
        expect(json['summary']['success'], 0);
        expect(json['summary']['warnings'], 0);
        expect(json['summary']['errors'], 0);
      });
    });
  });
}
