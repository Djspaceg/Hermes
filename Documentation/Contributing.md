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

3. Run from the command line while retaining runtime output:

   ```bash
   runtime_log=$(mktemp)
   pid_file=$(mktemp)
   run_token=$(/usr/bin/uuidgen)
   make run RUN_TOKEN="$run_token" PID_FILE="$pid_file" >"$runtime_log" 2>&1 &
   make_job=$!
   while [ ! -s "$pid_file" ]; do
       make_command=$(/bin/ps -ww -p "$make_job" -o command= 2>/dev/null)
       case "$make_command" in
       *"make run"*"RUN_TOKEN=$run_token"*) ;;
       *)
           wait "$make_job"
           exit 1
           ;;
       esac
       sleep 0.1
   done
   hermes_pid=$(<"$pid_file")
   ```

   `make run` blocks until Hermes exits. Stop only that launch with:

   ```bash
   make stop PID="$hermes_pid" TOKEN="$run_token"
   wait "$make_job" || true
   ```

   Do not use `tell application "Hermes" to quit`, `killall Hermes`, or a
   name-only `pgrep` result. Command-line launches are not addressable by
   AppleScript application name, and XCTest hosts also run with the process
   name `Hermes`. The `stop` target verifies the exact DerivedData executable
   recorded by this checkout and the per-launch token, then signals the
   launch's unique LaunchServices identity rather than a reusable process
   name. It remains valid if the current build configuration changes after
   launch.

   Before launching, inspect any existing name matches with
   `/bin/ps -ww -p <PID> -o pid=,ppid=,command=`. A bare `pgrep -x Hermes`
   cannot distinguish an app from another checkout's transient XCTest host.
   Use the full executable path and launch parent to identify the owning
   checkout, and never stop a process that this invocation did not create.

4. Run tests:

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
