# Development Conventions & Standards

## Mission: Modernization

This project has been in archival stasis for 7 years and is based on very old conventions. **Our goal is to modernize it completely and deliver the best possible version using current Apple technologies.**

When working on this codebase:

- **Aggressively modernize**: Don't preserve old patterns just because they exist
- **Question everything**: If it looks dated, it probably is
- **Refactor boldly**: We're not maintaining legacy code, we're transforming it
- **Target modern macOS**: macOS Tahoe (26.0) exclusively - use latest APIs without compatibility checks

## Core Principle: Built-in First

**If there's ever a question about which approach to use, opt FIRST for the built-in standard way of doing things BEFORE implementing your own solution.**

Custom code is only a fallback in case the built-in approach CANNOT do what we need. We are aiming for good structure, following the conventions and best practices of modern Apple macOS app development.

**We are NOT interested in:**

- Legacy code patterns
- Deprecated APIs or workarounds
- Hacks or non-standard solutions
- Reinventing functionality that exists in the platform

## Modern macOS Development Standards

### SwiftUI Best Practices

- Use native SwiftUI components and modifiers
- Leverage `@State`, `@Binding`, `@ObservedObject`, `@StateObject` appropriately
- Use `@Environment` for system values and custom environment keys
- Prefer declarative view composition over imperative logic
- Use `GeometryReader` sparingly and only when truly needed
- Leverage SwiftUI's built-in layout system (VStack, HStack, ZStack, etc.)

### State Management

- Use `@Published` properties in `ObservableObject` view models
- Centralize app-wide state in `AppState` singleton
- Use Combine publishers for reactive data flow
- Leverage `NotificationCenter` publishers for Objective-C bridge

### Naming Conventions

- **Swift**: camelCase for properties/methods, PascalCase for types
- **Objective-C**: camelCase with descriptive prefixes where appropriate
- **Files**: Match the primary type name (e.g., `LoginView.swift` for `LoginView`)
- **View Models**: Suffix with `ViewModel` (e.g., `LoginViewModel`)
- **Models**: Suffix with `Model` for Swift models (e.g., `SongModel`)

### Code Organization

- One primary type per file
- Group related functionality with `// MARK: - Section Name`
- Order: properties → initializers → lifecycle → public methods → private methods
- Keep view bodies concise; extract complex views into computed properties or separate views

### SwiftUI View Structure

```swift
struct MyView: View {
    // MARK: - Properties
    @ObservedObject var viewModel: MyViewModel
    @State private var localState: String = ""
    
    // MARK: - Body
    var body: some View {
        // Keep this minimal and readable
    }
    
    // MARK: - Subviews
    private var headerView: some View {
        // Extract complex sections
    }
}
```

### Objective-C Bridge

- Expose only what's necessary via bridging header
- Use `@objc` annotations sparingly in Swift
- Communicate via `NotificationCenter` for loose coupling
- Keep Objective-C focused on business logic, not UI

### Error Handling

- Use Swift's native error handling (`throws`, `do-catch`)
- Display errors via SwiftUI `ErrorView`
- Log errors appropriately for debugging
- Provide user-friendly error messages

### Async/Await

- Prefer Swift concurrency (`async`/`await`) for new code
- Use `Task` for bridging synchronous to asynchronous contexts
- Mark view model methods with `@MainActor` when updating UI state
- Avoid completion handlers in new Swift code

### Accessibility

- Provide `.accessibilityLabel()` for custom controls
- Use `.accessibilityHint()` for non-obvious interactions
- Ensure keyboard navigation works properly
- Test with VoiceOver enabled

### Performance

- Use `LazyVStack`/`LazyHStack` for large lists
- Avoid unnecessary view updates with `Equatable` conformance
- Profile before optimizing
- Let SwiftUI handle view diffing and updates

## What to Avoid

❌ **Don't** create custom solutions when SwiftUI provides built-in components  
❌ **Don't** use deprecated APIs (check documentation)  
❌ **Don't** implement workarounds for SwiftUI limitations without exhausting native options  
❌ **Don't** mix AppKit and SwiftUI unless absolutely necessary  
❌ **Don't** use force unwrapping (`!`) except in truly safe contexts  
❌ **Don't** ignore compiler warnings  

## What to Embrace

✅ **Do** use SwiftUI's native components and modifiers  
✅ **Do** follow Apple's Human Interface Guidelines  
✅ **Do** write declarative, composable views  
✅ **Do** leverage Swift's type system and safety features  
✅ **Do** use modern Swift concurrency patterns  
✅ **Do** target macOS Tahoe (26.0) exclusively - use latest APIs without compatibility checks  
✅ **Do** support dark mode and system appearance changes  
✅ **Do** respect user preferences and system settings  

## Recognizing Legacy Code

Signs you're looking at code that needs modernization:

🚩 **Red Flags:**

- XIB/NIB files or `IBOutlet`/`IBAction` annotations
- `NSViewController`, `NSWindowController` for UI
- Manual frame calculations or Auto Layout constraints in code
- Completion handler callbacks instead of async/await
- `addObserver`/`removeObserver` for notifications
- Delegate protocols for simple callbacks
- Force casts and force unwraps everywhere
- Massive view controller files (1000+ lines)
- Comments like "TODO: Fix this hack"

🔄 **Modernization Actions:**

- Replace with SwiftUI views and view models
- Use declarative layout and state management
- Convert to async/await or Combine
- Use `@Published` properties and publishers
- Replace with closures or async patterns
- Break into smaller, focused components
- Use proper Swift optionals and error handling
- Delete and rewrite cleanly

## Code Review Checklist

Before committing code, verify:

- [ ] Uses built-in APIs where available
- [ ] No deprecated APIs or warnings
- [ ] Follows Swift/SwiftUI naming conventions
- [ ] Properly handles errors
- [ ] Supports dark mode
- [ ] No force unwraps in unsafe contexts
- [ ] View models are `@MainActor` where appropriate
- [ ] Code is readable and well-organized
- [ ] No unnecessary custom implementations
- [ ] Removed any legacy patterns encountered
- [ ] Would pass review by an experienced Swift/SwiftUI developer
