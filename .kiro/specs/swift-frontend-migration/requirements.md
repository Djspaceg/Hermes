# Requirements Document: Swift Frontend Migration

## Introduction

This document specifies the requirements for properly migrating Hermes to a 100% Swift/SwiftUI frontend while keeping the Objective-C business logic layer (Pandora API, audio streaming, networking, cryptography). The migration must account for the existing XIB-based architecture and properly transition to SwiftUI's lifecycle.

## Glossary

- **Swift_Frontend**: All UI code written in Swift/SwiftUI
- **ObjC_Backend**: Business logic in Objective-C (Pandora, AudioStreamer, networking, crypto)
- **XIB_Dependencies**: Interface Builder files and IBOutlet connections
- **SwiftUI_Lifecycle**: App lifecycle managed by SwiftUI @main and WindowGroup
- **AppDelegate_Adapter**: Minimal AppDelegate for Objective-C integration via @NSApplicationDelegateAdaptor

## Requirements

### Requirement 1: Remove XIB Dependencies

**User Story:** As a developer, I want to remove all XIB dependencies, so that SwiftUI can manage the UI lifecycle.

#### Acceptance Criteria

1. THE app SHALL NOT load MainMenu.xib
2. THE Info.plist SHALL NOT contain NSMainNibFile or NSPrincipalClass keys
3. THE HermesAppDelegate SHALL NOT have IBOutlet properties for UI elements
4. THE window SHALL be created by SwiftUI WindowGroup, not by XIB
5. ALL UI controllers (AuthController, StationsController, etc.) SHALL NOT depend on XIB-loaded views

### Requirement 2: SwiftUI App Lifecycle

**User Story:** As a developer, I want SwiftUI to manage the app lifecycle, so that the app follows modern macOS patterns.

#### Acceptance Criteria

1. THE app SHALL use @main on a SwiftUI App struct as the entry point
2. THE app SHALL use @NSApplicationDelegateAdaptor for Objective-C integration
3. THE app SHALL use WindowGroup to create windows
4. THE main.m file SHALL be removed from the build
5. THE AppDelegate SHALL only handle Objective-C business logic, not UI

### Requirement 3: Minimal AppDelegate

**User Story:** As a developer, I want a minimal AppDelegate that only handles Objective-C integration, so that Swift owns the UI completely.

#### Acceptance Criteria

1. THE AppDelegate SHALL NOT have window or view properties
2. THE AppDelegate SHALL only set up notification observers
3. THE AppDelegate SHALL only handle Pandora API callbacks
4. THE AppDelegate SHALL NOT call setCurrentView or manage UI state
5. THE AppDelegate SHALL be adapted via @NSApplicationDelegateAdaptor

### Requirement 4: Swift-Managed Authentication

**User Story:** As a user, I want the app to handle authentication through SwiftUI, so that I see a modern login experience.

#### Acceptance Criteria

1. WHEN the app launches without credentials THEN SwiftUI SHALL show LoginView
2. WHEN the app launches with saved credentials THEN SwiftUI SHALL auto-authenticate
3. THE authentication flow SHALL be managed by Swift AppState and LoginViewModel
4. THE Objective-C AuthController SHALL NOT be used
5. THE authentication SHALL call Objective-C Pandora API methods

### Requirement 5: Swift-Managed UI State

**User Story:** As a developer, I want Swift to manage all UI state, so that there's a single source of truth.

#### Acceptance Criteria

1. THE AppState SHALL manage currentView state (login, loading, player, error)
2. THE Objective-C code SHALL NOT call setCurrentView
3. THE Objective-C code SHALL post notifications that Swift observes
4. THE Swift code SHALL update UI state based on notifications
5. THE UI state SHALL drive what SwiftUI views are displayed

### Requirement 6: Proper Sidebar Implementation

**User Story:** As a user, I want a properly structured sidebar with navigation, so that I can access stations and history.

#### Acceptance Criteria

1. THE sidebar SHALL have fixed navigation header with Stations/History buttons
2. THE sidebar SHALL have conditional sort controls (Name/Date for Stations)
3. THE sidebar SHALL have scrollable content area
4. THE sidebar SHALL have conditional footer buttons (different for Stations vs History)
5. THE sidebar SHALL be collapsible via toggle button

### Requirement 7: Responsive Album Art

**User Story:** As a user, I want album art that scales properly, so that it looks good at any window size.

#### Acceptance Criteria

1. THE album art SHALL use GeometryReader for responsive sizing
2. THE album art SHALL scale based on available space (max 600pt)
3. THE album art SHALL maintain aspect ratio
4. THE album art SHALL expand when sidebar collapses
5. THE window SHALL have no minimum size constraints from album art

### Requirement 8: Clean Architecture

**User Story:** As a developer, I want clean separation between Swift UI and Objective-C business logic, so that the code is maintainable.

#### Acceptance Criteria

1. THE Swift code SHALL only import Objective-C classes via bridging header
2. THE Objective-C code SHALL NOT import or reference Swift classes
3. THE communication SHALL flow via notifications (ObjC → Swift) and method calls (Swift → ObjC)
4. THE Swift code SHALL wrap Objective-C models in Swift-friendly wrappers
5. THE architecture SHALL have clear boundaries between layers
