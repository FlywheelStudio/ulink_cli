import 'dart:io';
import 'package:test/test.dart';
import 'package:ulink_cli/models/target_info.dart';

void main() {
  group('TargetInfo', () {
    test('should create TargetInfo with all fields', () {
      final entitlements = File('/path/to/MyApp.entitlements');
      final infoPlist = File('/path/to/Info.plist');

      final target = TargetInfo(
        entitlementsFile: entitlements,
        infoPlistFile: infoPlist,
        bundleId: 'com.example.myapp',
        targetName: 'MyApp',
      );

      expect(target.entitlementsFile, entitlements);
      expect(target.infoPlistFile, infoPlist);
      expect(target.bundleId, 'com.example.myapp');
      expect(target.targetName, 'MyApp');
    });
  });

  group('TargetDiscoveryResult', () {
    test('hasMatch returns true when matchedTarget is not null', () {
      final target = TargetInfo(
        entitlementsFile: File('/path/to/MyApp.entitlements'),
        infoPlistFile: File('/path/to/Info.plist'),
        bundleId: 'com.example.myapp',
        targetName: 'MyApp',
      );

      final result = TargetDiscoveryResult(
        matchedTarget: target,
        allTargets: [target],
        requestedBundleId: 'com.example.myapp',
      );

      expect(result.hasMatch, isTrue);
    });

    test('hasMatch returns false when matchedTarget is null', () {
      final result = TargetDiscoveryResult(
        matchedTarget: null,
        allTargets: [],
        requestedBundleId: 'com.example.myapp',
      );

      expect(result.hasMatch, isFalse);
    });

    test('hasMultipleTargets returns true when more than one target', () {
      final target1 = TargetInfo(
        entitlementsFile: File('/path/to/MyApp.entitlements'),
        infoPlistFile: File('/path/to/Info.plist'),
        bundleId: 'com.example.myapp',
        targetName: 'MyApp',
      );
      final target2 = TargetInfo(
        entitlementsFile: File('/path/to/MyAppFree.entitlements'),
        infoPlistFile: File('/path/to/Info.plist'),
        bundleId: 'com.example.myappfree',
        targetName: 'MyAppFree',
      );

      final result = TargetDiscoveryResult(
        matchedTarget: target1,
        allTargets: [target1, target2],
        requestedBundleId: 'com.example.myapp',
      );

      expect(result.hasMultipleTargets, isTrue);
    });

    test('hasMultipleTargets returns false when one or zero targets', () {
      final result = TargetDiscoveryResult(
        matchedTarget: null,
        allTargets: [],
        requestedBundleId: null,
      );

      expect(result.hasMultipleTargets, isFalse);
    });
  });
}
