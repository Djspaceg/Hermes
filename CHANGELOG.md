# Version 2.0.0 (unreleased)

[Full changelog](https://github.com/HermesApp/Hermes/compare/v1.3.1...HEAD)

**Complete rewrite for modern macOS.** After 7 years of dormancy, Hermes has been rebuilt from the ground up.

### Breaking Changes

* [changed] Minimum macOS version is now **Tahoe (26.0)**
* [changed] Entire UI rewritten in SwiftUI — no more XIBs or legacy AppKit views
* [removed] Growl support removed (use native macOS notifications)
* [removed] Legacy drawer-based UI replaced with modern sidebar

### New Features

* [added] Liquid Glass design with translucent controls using `.glassEffect()` modifier
* [added] Full-window album artwork as player background
* [added] Dedicated album art preview window with fullscreen support
* [added] Modern sidebar with stations list and integrated history view
* [added] Rich menu bar integration with album artwork thumbnail
* [added] Configurable menu bar icon: color, monochrome, or album art
* [added] Tabbed preferences with General, Playback, and Network sections
* [added] Station artwork caching for faster loading
* [added] Comprehensive unit test suite

### Improvements

* [changed] Swift 5.0+ with modern language features throughout
* [changed] Async/await patterns for all asynchronous operations
* [changed] Proper error handling with clear UI feedback
* [changed] Automatic token refresh — no more random logouts
* [changed] Better handling of network interruptions and reconnections
* [changed] Improved memory management and performance
* [changed] Media keys handled via MPRemoteCommandCenter (modern macOS API)

### Architecture

* [changed] SwiftUI views with MVVM architecture
* [changed] View models using `@ObservableObject` and `@Published`
* [changed] Centralized app state management via `AppState` singleton
* [changed] NotificationCenter bridge for Swift/Objective-C communication
* [changed] Window IDs centralized in `WindowID` constants

---

# Version 1.3.1 (3/26/17)

[Full changelog](https://github.com/HermesApp/Hermes/compare/v1.3.0...v1.3.1)

* [added by @paullj1] Allow display of play/pause status in the Dock to be disabled (#278)
* [added by @paullj1] Add "Skip" button to macOS song notifications
* [added by @nriley] Better distinguish the play/pause icon from the album art in the Dock (#277)
* [added by @nriley] Use native Touch Bar controls (when Hermes is not the active application) in macOS 10.12.2 and later (#287)
* [added by @brettpynn] Provide notification of stream stopping when Hermes is quit (#293)
* [changed by @nriley] Clarify "thumbs up" and "rating" in scripting (#196)
* [fixed by @nriley] Fix "current song" reference in scripting
* [fixed by @nriley] Work around a regression in macOS 10.12 which caused issues when showing drawers
* [fixed by @elemongw] Fix checking then unchecking "Use proxy for audio" leaving proxy enabled (#290)
* [fixed by @nriley] Don't crash, instead display a message when proxy information is invalid
* [fixed by @yerke] Work around Pandora API returning errors in user.canSubscribe (#296)
* [fixed by @grimreaper] Several code cleanups (#283)

# Version 1.3.0 (9/20/16)

[Full changelog](https://github.com/HermesApp/Hermes/compare/v1.2.8...v1.3.0)

* [added by @paullj1] Allow skipping songs (if using banners) and liking/disliking songs (if using alerts) from macOS notifications (#273)
* [added by @paullj1] Optionally show album art and/or track titles in the menu bar (#208, #275)
* [added by @paullj1] Optionally show album art and play/pause status in the Dock (#275)
* [added by @paullj1 and @nriley] Display currently playing station in menubar and Dock menu
* [changed by @paullj1] Make Hermes macOS song notifications look more like iTunes notifications (#273)
* [changed by @nriley] Simplify and reduce screen space used by main window
* [fixed by @nriley] Allow the Hermes to appear over fullscreen applications when the Dock icon is hidden
* [fixed by @nriley] Work around OS X 10.10 bug causing strange drawer background coloring
* [fixed by @nriley] Work around macOS 10.12 bug causing volume slider and song progress not to display
* [fixed by @nriley] More reliably respond to the play/pause keyboard shortcut (space bar)
* [fixed by @nriley] Properly show the About Hermes window when Hermes' Dock icon is hidden

# Version 1.2.8 (6/24/16)

[Full changelog](https://github.com/HermesApp/Hermes/compare/v1.2.7...v1.2.8)

* [changed by @nriley] Fix a regression introduced in 1.2.7 which degraded audio quality for non-Pandora One users (#263)
* [changed by @nriley] Always display Shuffle (formerly QuickMix) at the top of the station list, more like the Pandora Web site
* [changed by @reedloden] Scrobble securely where possible
* [added by @nriley] Only display song/artist/album arrows in the playback screen on mouseover
* [added by @nriley] Allow double-clicking seeds or genres to create a station or add a seed
* [added by @nriley] Allow the likes/dislikes lists in the Edit Station window to be sorted (#266)
* [added by @nriley] Save the size and position of the Edit Station window
* [added by @nriley] Sort station genres and improve their display
* [added by @nriley] Show playback date/time with tooltips in history drawer
* [added by @nriley] Sign with Developer ID for Gatekeeper
* [fixed by @nriley] Don't allow the drawer or toolbar to be used before you're logged into Pandora (#170)
* [fixed by @nriley] Display the station drawer when asking the user to "Choose a station" (#170)
* [fixed by @nriley] Don't crash when adding or removing seeds from a station
* [fixed by @nriley] Don't show the add station sheet after dismissing another sheet
* [fixed by @nriley] Fix search results showing up in unexpected places
* [fixed by @nriley] Allow clicking on album art in the history drawer (#178)
* [fixed by @nriley] Improve history display (e.g. no longer scrolls to/selects the oldest song)
* [fixed by @nriley] Better handle deleting the current station
* [fixed by @nriley] Allow editing seeds in genre stations (#267)
* [fixed by @nriley] Immediately reflect changes to likes/dislikes in the Edit Station window
* [fixed by @nriley] Display a progress indicator rather than appearing to get "stuck" when changing stations

# Version 1.2.7 and earlier

See [GitHub releases](https://github.com/HermesApp/Hermes/releases) for historical changelog.
