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

Hermes is currently undergoing a migration from Objective-C/XIB to Swift/SwiftUI:

- **Business Logic Layer**: Objective-C (Pandora API, audio streaming, networking, crypto, keychain)
- **UI Layer**: SwiftUI (views, view models, state management)
- **Bridge**: Notification-based communication between layers

The app targets macOS Tahoe (26.0) and later exclusively.

## User Workflow

1. User authenticates with Pandora credentials (stored in keychain)
2. App fetches and displays user's stations in sidebar
3. User selects and plays a station
4. Audio streams and displays current song with album art
5. User can rate songs, skip tracks, manage stations, and view history
