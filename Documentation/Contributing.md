# Contributing to Hermes

We welcome contributions! Here's how to get started.

## Development Setup

1. Clone the repository:

   ```bash
   git clone https://github.com/HermesApp/Hermes.git
   cd Hermes
   ```

2. Open in Xcode or build from command line:

   ```bash
   make                    # Debug build
   make CONFIGURATION=Release  # Release build
   ```

3. Run tests:

   ```bash
   make test
   ```

## Code Style

### Swift

- Use SwiftUI for all new UI code
- Follow Apple's Swift API Design Guidelines
- Use `@ObservableObject` view models with `@Published` properties
- Prefer async/await over completion handlers
- Use meaningful variable names over single letters

### File Organization

- One primary type per file
- Group related code with `// MARK: - Section Name`
- Order: properties → initializers → body/lifecycle → public methods → private methods

### SwiftUI Views

```swift
struct MyView: View {
    // MARK: - Properties
    @ObservedObject var viewModel: MyViewModel
    @State private var localState = false
    
    // MARK: - Body
    var body: some View {
        // Keep minimal and readable
    }
    
    // MARK: - Subviews
    private var headerView: some View {
        // Extract complex sections
    }
}
```

## Architecture

### Layers

- **Views** (`Sources/Swift/Views/`) — SwiftUI views only
- **View Models** (`Sources/Swift/ViewModels/`) — Business logic and state
- **Services** (`Sources/Swift/Services/`) — Pandora API, audio, networking
- **Models** (`Sources/Swift/Models/`) — Data structures

### State Management

- `AppState` singleton for app-wide state
- View models for feature-specific state
- `NotificationCenter` for cross-layer communication

### Constants

- Window IDs in `WindowID` enum (`Constants.swift`)
- UserDefaults keys in `UserDefaultsKeys.swift`
- Notification names in `NotificationNames.swift`

## Testing

- Add unit tests for new functionality in `HermesTests/Tests/`
- Use mock objects from `HermesTests/Mocks/` or `PreviewMocks.swift`
- Run tests before submitting PRs

## Pull Request Guidelines

1. Create a feature branch from `main`
2. Make focused, atomic commits
3. Write clear commit messages
4. Ensure all tests pass
5. Update documentation if needed
6. Submit PR with description of changes

## What We're Looking For

- Bug fixes with test coverage
- Performance improvements
- Accessibility enhancements
- Documentation improvements
- New features that align with Hermes's purpose

## Questions?

Open an issue or start a discussion on GitHub.
