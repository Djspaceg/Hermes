# Product Overview

Hermes is a native macOS Pandora client that provides a streamlined music streaming experience with system integration.

## Project Status

**This is a modernization effort.** The project was in archival stasis for 7 years and is based on very old conventions. Our mission is to modernize it and create the best possible version using current Apple technologies and best practices.

## Core Features

- Pandora music streaming with authentication
- Station management (create, rename, delete, play)
- Playback controls (play/pause, skip, volume, thumbs up/down, tired of song)
- Listening history tracking
- Album artwork display
- System integration:
  - Media key support (play/pause, next track)
  - Native macOS notifications for song changes
  - Last.fm scrobbling support
  - AppleScript support for automation
  - Status bar menu integration
- Modern macOS design with dark mode support and translucent vibrancy effects

## Architecture

Hermes uses Swift across its current application source:

- **Business Logic**: Swift services for Pandora, playback, audio streaming, networking, crypto, keychain, and Last.fm
- **UI Layer**: SwiftUI views with Swift Observation-based models and view models
- **Internal Communication**: Direct Swift dependencies plus typed `NotificationCenter`/Combine event streams
- **System Integration**: Swift types interoperate with Cocoa/AppKit and AppleScript runtime APIs where required

The app targets macOS Tahoe (26.0) and later exclusively.

**Architecture correction (verified 2026-09-17):** The historical Objective-C/XIB migration is complete for application source. The current target has no Objective-C/C source files and no Swift bridging-header setting.

## User Workflow

1. User authenticates with Pandora credentials (stored in keychain)
2. App fetches and displays user's stations in sidebar
3. User selects and plays a station
4. Audio streams and displays current song with album art
5. User can rate songs, skip tracks, manage stations, and view history
