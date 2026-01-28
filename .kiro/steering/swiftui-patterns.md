# SwiftUI View Composition Patterns

Guidelines for organizing and structuring SwiftUI views in this project.

## View File Organization

Structure view files in this order:

1. **Protocol definitions** (if any)
2. **Main view struct**
3. **Private helper views** (used only by main view)
4. **Reusable components** (could be used elsewhere)
5. **Previews** (at the bottom)

```swift
// MARK: - Protocol (if needed)
protocol SomeProtocol { }

// MARK: - Main View
struct MainView: View { }

// MARK: - Private Helpers
private struct HelperView: View { }

// MARK: - Reusable Components
struct ReusableComponent: View { }

// MARK: - Previews
#Preview("Name") { }
```

## Property Organization

Group properties by type, in this order:

```swift
struct MyView: View {
    // Observed objects first
    @ObservedObject var viewModel: MyViewModel
    
    // State properties grouped together
    @State private var isExpanded = false
    @State private var selectedItem: Item?
    
    // Environment values grouped together
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    
    // Constants last
    private let maxWidth: CGFloat = 500
}
```

## View Body Decomposition

Keep `body` minimal. Extract complex sections into computed properties or subviews:

```swift
var body: some View {
    ZStack {
        backgroundLayer
        contentLayer
        overlayLayer
    }
}

// MARK: - Subviews

private var backgroundLayer: some View { ... }
private var contentLayer: some View { ... }

@ViewBuilder
private var overlayLayer: some View {
    if showOverlay {
        OverlayView()
    }
}
```

Use `@ViewBuilder` for conditional content. Use `@ToolbarContentBuilder` for toolbar items.

## Modifier Ordering

Apply modifiers in this order (inside → outside):

1. **Content** - `.font()`, `.foregroundColor()`, `.lineLimit()`
2. **Layout** - `.frame()`, `.padding()`
3. **Background/Overlay** - `.background()`, `.overlay()`
4. **Shape/Clipping** - `.clipShape()`, `.cornerRadius()`
5. **Effects** - `.shadow()`, `.opacity()`, `.blur()`
6. **Interaction** - `.onTapGesture()`, `.help()`, `.disabled()`
7. **Animation** - `.animation()`

```swift
Text("Hello")
    .font(.headline)           // 1. Content
    .padding()                 // 2. Layout
    .background(.blue)         // 3. Background
    .clipShape(RoundedRectangle(cornerRadius: 8))  // 4. Shape
    .shadow(radius: 2)         // 5. Effects
    .onTapGesture { }          // 6. Interaction
```

## Modifier Placement

Apply modifiers at the appropriate level:

- **Components define their internal layout** - padding, spacing within
- **Parent views handle spacing between siblings** - gaps, margins
- **Don't double-apply** - if padding is inside a component, don't add more outside

```swift
// ❌ Bad: padding applied at multiple levels
ProgressBar()
    .padding(.horizontal, 8)  // Already has internal padding!
    .padding(.bottom, 8)

// ✅ Good: component handles its own padding
ProgressBar()  // Internal padding defined inside
```

## Shared Styling

Extract repeated styling into View extensions in `ViewModifiers.swift`:

```swift
// In ViewModifiers.swift
extension View {
    func contentOnGlass() -> some View {
        self.shadow(color: .black.opacity(0.5), radius: 1)
    }
}

// Usage
Text("Song Title")
    .foregroundColor(.white)
    .contentOnGlass()
```

## Component Design

Components should be:

- **Self-contained** - define their own internal layout
- **Configurable via parameters** - not hardcoded values
- **Single responsibility** - do one thing well

```swift
// ✅ Good: self-contained, configurable
struct PlayPauseButton: View {
    let isPlaying: Bool
    let action: () -> Void
    
    private let size: CGFloat = 96
    
    var body: some View {
        Button(action: action) {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
        }
        .frame(width: size, height: size)
        .glassEffect(.regular.interactive(), in: .circle)
    }
}
```

## Layout Patterns

Use ZStack with alignment for overlay positioning:

```swift
ZStack {
    // Centered content (default alignment)
    CenteredButton()
    
    // Positioned content using frame alignment
    InfoView()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    
    VolumeControl()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
}
```

## Previews

Keep previews minimal and focused:

```swift
#Preview("Playing") {
    PlayerView(viewModel: PreviewPlayerViewModel(isPlaying: true))
        .frame(width: 600, height: 400)
}

#Preview("Empty") {
    PlayerView(viewModel: PreviewPlayerViewModel(song: nil))
        .frame(width: 600, height: 400)
}
```

## When to Extract

Extract to a separate view when:

- Code is reused in multiple places
- A section has its own state or logic
- The parent view body exceeds ~50 lines
- A logical grouping emerges (e.g., "all the playback controls")

Keep inline when:

- It's a simple, one-off layout
- Extracting would require passing many parameters
- The code is clearer inline
