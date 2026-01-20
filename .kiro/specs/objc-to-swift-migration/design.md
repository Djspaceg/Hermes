# Design Document: Objective-C to Swift Migration

## Overview

This design outlines the approach for migrating remaining Objective-C code in Hermes to modern Swift while preserving core business logic. The migration follows a phased approach, starting with simple deletions and constants, progressing to utility code, and finally tackling complex integrations.

## Architecture

### Current State

```
Hermes Codebase
├── Swift (UI Layer)
│   ├── SwiftUI Views
│   ├── View Models
│   ├── Models
│   └── Utilities (partial)
├── Objective-C (Business Logic + Legacy)
│   ├── Pandora API (keep)
│   ├── AudioStreamer (keep)
│   ├── PlaybackController (keep)
│   ├── Utilities (migrate)
│   └── Integrations (migrate)
└── Bridge
    ├── NotificationCenter
    └── Bridging Header
```

### Target State

```
Hermes Codebase
├── Swift (UI + Most Logic)
│   ├── SwiftUI Views
│   ├── View Models
│   ├── Models
│   ├── Utilities (all)
│   └── Services (integrations)
├── Objective-C (Core Business Logic Only)
│   ├── Pandora API
│   ├── AudioStreamer
│   └── PlaybackController
└── Bridge
    ├── NotificationCenter
    └── Minimal Bridging Header
```

## Components and Interfaces

### Phase 3: Quick Wins (Constants & Utilities)

#### Component: NotificationNames (COMPLETE)

- **Input**: Notification.Name strings
- **Output**: Type-safe notification references
- **Implementation**: Swift extension on Notification.Name
- **Status**: ✅ Migrated

#### Component: HermesConstants

- **Input**: C preprocessor macros
- **Output**: Swift enums and structs
- **Implementation**: Keep HermesConstants.h for Objective-C, use inline constants in Swift
- **Status**: ⏳ Deferred (Xcode project file management issues)

#### Component: Keychain

- **Input**: Username/password pairs
- **Output**: Keychain storage operations
- **Implementation**: KeychainManager.swift already exists
- **Status**: ⏳ Pending (Scrobbler and Pandora still use old API)

### Phase 4: Modernization (Networking & Images)

#### Component: ImageLoader

- **Current**: Custom async image loading with callbacks
- **Target**: SwiftUI AsyncImage + URLCache
- **Interface**:

```swift
// Old: ImageLoader.loadImageURL(_:callback:)
// New: AsyncImage(url: URL)
```

#### Component: NetworkConnection

- **Current**: Custom reachability monitoring
- **Target**: NWPathMonitor from Network framework
- **Interface**:

```swift
class NetworkMonitor: ObservableObject {
    @Published var isConnected: Bool
    func startMonitoring()
    func stopMonitoring()
}
```

#### Component: URLConnection

- **Current**: NSURLSession wrapper with completion handlers
- **Target**: URLSession with async/await
- **Interface**:

```swift
class HTTPClient {
    func request(_ url: URL) async throws -> Data
    func applyProxyConfiguration(_ config: URLSessionConfiguration)
}
```

### Phase 5: Advanced Migrations

#### Component: Scrobbler (Last.fm Integration)

- **Current**: FMEngine wrapper with callbacks
- **Target**: Modern Swift service with async/await
- **Interface**:

```swift
@MainActor
class LastFMService: ObservableObject {
    func scrobble(_ song: Song, state: ScrobbleState) async throws
    func setPreference(_ song: Song, loved: Bool) async throws
    func authenticate() async throws
}
```

#### Component: AppleScript Support

- **Current**: Objective-C AppleScript handlers
- **Target**: Swift with @objc compatibility
- **Interface**:

```swift
@objc class AppleScriptSupport: NSObject {
    @objc func handleCommand(_ command: NSScriptCommand) -> Any?
}
```

#### Component: HermesApp Singleton

- **Current**: Objective-C app singleton
- **Target**: Already replaced by AppState.swift
- **Action**: Delete old files

## Data Models

### Migration Task Model

```swift
struct MigrationTask {
    let id: Int
    let name: String
    let status: TaskStatus
    let priority: Priority
    let estimatedEffort: TimeInterval
    let files: [FileOperation]
    
    enum TaskStatus {
        case notStarted
        case inProgress
        case complete
    }
    
    enum Priority {
        case high, medium, low
    }
    
    struct FileOperation {
        let action: Action
        let path: String
        
        enum Action {
            case delete, create, update
        }
    }
}
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system - essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Build Integrity After Migration

*For any* completed migration task, building the project should succeed with zero compilation errors.
**Validates: Requirements 1.1**

### Property 2: Test Suite Stability

*For any* completed migration task, running the test suite should result in all 50 tests passing.
**Validates: Requirements 1.2**

### Property 3: Functionality Preservation

*For any* migrated component, the behavior should be identical to the original Objective-C implementation.
**Validates: Requirements 1.3**

### Property 4: Project File Validity

*For any* modification to project.pbxproj, the file should remain parseable by Xcode without errors.
**Validates: Requirements 7.2**

### Property 5: Core Business Logic Preservation

*For any* migration task, files in the Core_Business_Logic set (PlaybackController, Pandora API, AudioStreamer) should not be modified or deleted.
**Validates: Requirements 6.1, 6.2, 6.3**

### Property 6: Progress Tracking Accuracy

*For any* completed task, the progress tracking document should reflect the updated completion count and time spent.
**Validates: Requirements 8.1, 8.4**

## Error Handling

### Project File Corruption

- **Detection**: Xcode reports "unable to read project" or JSON parse errors
- **Recovery**: `git checkout Hermes.xcodeproj/project.pbxproj`
- **Prevention**: Use manual sed commands with verification, avoid Python scripts that modify project.pbxproj

### Build Failures

- **Detection**: `make` returns non-zero exit code
- **Diagnosis**: Check `make 2>&1 | grep "error:"` for specific errors
- **Recovery**: Revert file changes, investigate root cause
- **Prevention**: Build after each file change

### Test Failures

- **Detection**: xcodebuild test reports failed tests
- **Diagnosis**: Review test output for specific failures
- **Recovery**: Fix implementation or revert changes
- **Prevention**: Run tests after each migration

### Missing Dependencies

- **Detection**: "Cannot find 'X' in scope" errors
- **Cause**: Swift file not added to Xcode project
- **Recovery**: Manually add file references to project.pbxproj or use inline definitions
- **Prevention**: Verify file is in project after creation

## Testing Strategy

### Unit Testing

- Run existing 50-test suite after each migration
- Tests verify behavior parity, not implementation details
- Tests should not pollute UserDefaults or Keychain
- Use mocks to avoid side effects in tests

### Integration Testing

- Manual testing of migrated features in running app
- Verify UI interactions work correctly
- Test with real Pandora account for API integrations
- Verify system integrations (media keys, notifications, scrobbling)

### Property-Based Testing

- Not applicable for this migration (behavior preservation, not new logic)
- Focus on regression testing with existing unit tests

### Build Verification

- Build must succeed with zero errors after each task
- Zero warnings preferred
- Verify in both Debug and Release configurations

### Migration Verification Checklist

After each task:

1. ✅ Build succeeds (`make CONFIGURATION=Debug`)
2. ✅ All tests pass (`xcodebuild test`)
3. ✅ No new warnings introduced
4. ✅ Functionality verified manually (if applicable)
5. ✅ Progress tracking updated
6. ✅ Git commit with clear message
