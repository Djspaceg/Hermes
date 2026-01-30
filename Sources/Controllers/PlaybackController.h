/**
 * @file PlaybackController.h
 * @brief Playback controller for managing audio playback
 *
 * This controller handles the business logic for playing stations,
 * managing playback state, and coordinating with the Pandora API.
 * UI is handled separately by SwiftUI views.
 */

#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>

#import "Pandora/Station.h"

@class Song;

/// Notification posted when playback state changes (playing/paused/stopped)
extern NSString * const PlaybackStateDidChangeNotification;

/// Notification posted when a new song starts playing
extern NSString * const PlaybackSongDidChangeNotification;

/// Notification posted when song progress updates
extern NSString * const PlaybackProgressDidChangeNotification;

/// Notification posted when album art is loaded
extern NSString * const PlaybackArtDidLoadNotification;

@interface PlaybackController : NSObject

// MARK: - Properties

/// The currently playing station
@property (nonatomic, readonly) Station *playing;

/// The current song's album art image data
@property (nonatomic, readonly) NSData *lastImg;

/// The current song's album art as NSImage
@property (nonatomic, readonly) NSImage *artImage;

/// Whether playback was paused by screensaver
@property (nonatomic) BOOL pausedByScreensaver;

/// Whether playback was paused by screen lock
@property (nonatomic) BOOL pausedByScreenLock;

/// Media remote command center for system media controls
@property (nonatomic, readonly) MPRemoteCommandCenter *remoteCommandCenter;

/// Current playback progress in seconds
@property (nonatomic, readonly) double currentProgress;

/// Current song duration in seconds
@property (nonatomic, readonly) double currentDuration;

/// Current volume (0-100)
@property (nonatomic) NSInteger volume;

// MARK: - Class Methods

+ (void)setPlayOnStart:(BOOL)play;
+ (BOOL)playOnStart;

// MARK: - Lifecycle

/// Initialize the controller and set up notification observers
- (void)setup;

/// Prepare for first use (load saved volume, etc.)
- (void)prepareFirst;

/// Set up or tear down media key handlers based on user preference
- (void)setupMediaKeys;

// MARK: - Station Management

/// Play a station (or nil to stop)
- (void)playStation:(Station *)station;

/// Reset playback state and clear saved station
- (void)reset;

/// Save current playback state
- (BOOL)saveState;

// MARK: - Playback Controls

/// Start or resume playback
- (BOOL)play;

/// Pause playback
- (BOOL)pause;

/// Stop playback
- (void)stop;

/// Toggle play/pause
- (void)playpause;

/// Skip to next song
- (void)next;

// MARK: - Song Rating

/// Rate a song (like or dislike)
- (void)rate:(Song *)song as:(BOOL)liked;

/// Like the current song
- (void)likeCurrent;

/// Dislike the current song
- (void)dislikeCurrent;

/// Mark current song as "tired of"
- (void)tiredOfCurrent;

// MARK: - Volume Control

- (void)increaseVolume;
- (void)decreaseVolume;

@end
