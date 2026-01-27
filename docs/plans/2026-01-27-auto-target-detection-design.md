# Auto Target Detection by Bundle ID

## Problem

iOS projects often have multiple targets (e.g., paid and free versions), each with their own entitlements file. The current CLI just picks the first `.entitlements` file it finds, which may be the wrong one.

## Solution

Automatically detect which local target to verify based on the bundle ID configured in the ULink project. The ULink project drives which local target gets verified - no user selection needed.

## Design

### New Data Structures

**File:** `lib/models/target_info.dart`

```dart
class TargetInfo {
  final File entitlementsFile;
  final File infoPlistFile;
  final String bundleId;
  final String targetName;  // Derived from parent folder name
}

class TargetDiscoveryResult {
  final TargetInfo? matchedTarget;
  final List<TargetInfo> allTargets;
  final String? requestedBundleId;

  bool get hasMatch => matchedTarget != null;
  bool get hasMultipleTargets => allTargets.length > 1;
}
```

### New Methods in ProjectDetector

**File:** `lib/parsers/project_detector.dart`

```dart
/// Find all entitlements files in the project
static List<File> findAllEntitlements(String projectPath, ProjectType projectType)

/// Discover target by bundle ID, returns all found targets plus the match
static TargetDiscoveryResult discoverTargetByBundleId(
  String projectPath,
  ProjectType projectType,
  String? targetBundleId,  // null = return first target (fallback)
)
```

### Info.plist to Entitlements Matching Algorithm

For each `.entitlements` file found:
1. Check same directory for `Info.plist`
2. Check parent directory for `Info.plist`
3. Check sibling directories one level deep for `Info.plist`
4. Search within the target folder recursively as fallback

Once Info.plist is found, extract bundle ID using existing `IosParser.parseInfoPlist()` logic.

If an entitlements file has no associated Info.plist, skip it with a debug log.

### Updated Verify Command Flow

1. **Fetch ULink config first** - Move API call earlier (before local parsing)
2. **Extract target bundle ID** - Get `ulinkConfig.iosBundleIdentifier`
3. **Auto-locate matching target** - Call `discoverTargetByBundleId()`
4. **Handle no match** - Show helpful error listing all discovered targets
5. **Proceed with matched target** - Continue with existing validation flow

### Error Messages

**No entitlements files found:**
```
Warning: No entitlements files found in project
  Add an entitlements file with com.apple.developer.associated-domains
```

**No match for ULink bundle ID:**
```
Error: No local target matches ULink bundle ID: com.example.myapp

  Found 2 targets in project:
    - MyAppFree (com.example.myappfree)
      MyAppFree/MyAppFree.entitlements
    - MyAppPro (com.example.myapppro)
      MyAppPro/MyAppPro.entitlements

  Either update your ULink iOS Bundle Identifier, or ensure the correct
  target has an entitlements file with associated domains configured.
```

**No credentials (fallback mode):**
```
Warning: No ULink credentials - using first target found: MyApp
  Run "ulink login" for automatic target matching by bundle ID
```

**Match found:**
```
Success: Matched target: MyApp (com.example.myapp)
```

## Files to Modify

1. **Create:** `lib/models/target_info.dart` - New data structures
2. **Modify:** `lib/parsers/project_detector.dart` - Add `findAllEntitlements()` and `discoverTargetByBundleId()`
3. **Modify:** `lib/commands/verify_command.dart` - Reorder flow, use new target discovery
4. **Create:** Tests for new functionality

## Fallback Behavior

When no ULink credentials are available, fall back to current behavior (first entitlements file found) with a warning message suggesting to log in for automatic target matching.
