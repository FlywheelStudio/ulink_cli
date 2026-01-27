import 'dart:io';

/// Information about an iOS target discovered in the project
class TargetInfo {
  final File entitlementsFile;
  final File infoPlistFile;
  final String bundleId;
  final String targetName;

  TargetInfo({
    required this.entitlementsFile,
    required this.infoPlistFile,
    required this.bundleId,
    required this.targetName,
  });
}

/// Result of target discovery operation
class TargetDiscoveryResult {
  final TargetInfo? matchedTarget;
  final List<TargetInfo> allTargets;
  final String? requestedBundleId;

  TargetDiscoveryResult({
    required this.matchedTarget,
    required this.allTargets,
    required this.requestedBundleId,
  });

  /// Whether a matching target was found
  bool get hasMatch => matchedTarget != null;

  /// Whether multiple targets were discovered in the project
  bool get hasMultipleTargets => allTargets.length > 1;
}
