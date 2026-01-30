/**
 * @file PlaybackController.m
 * @brief Implementation of the playback controller
 *
 * Handles all business logic for playing stations, managing playback state,
 * and coordinating with the Pandora API. UI updates are communicated via
 * NotificationCenter for SwiftUI to observe.
 */

#import <MediaPlayer/MediaPlayer.h>

#import "PlaybackController.h"
#import "Hermes-Swift.h"
#import "HermesConstants.h"
#import "Pandora/Pandora.h"

// MARK: - Notification Names

NSString * const PlaybackStateDidChangeNotification = @"PlaybackStateDidChangeNotification";
NSString * const PlaybackSongDidChangeNotification = @"PlaybackSongDidChangeNotification";
NSString * const PlaybackProgressDidChangeNotification = @"PlaybackProgressDidChangeNotification";
NSString * const PlaybackArtDidLoadNotification = @"PlaybackArtDidLoadNotification";

// MARK: - Private

static BOOL playOnStart = YES;

@interface PlaybackController ()

@property (nonatomic, readwrite) Station *playing;
@property (nonatomic, readwrite) NSData *lastImg;
@property (nonatomic, readwrite) NSImage *artImage;
@property (nonatomic, readwrite) MPRemoteCommandCenter *remoteCommandCenter;

@property (nonatomic) NSTimer *progressUpdateTimer;
@property (nonatomic) BOOL scrobbleSent;
@property (nonatomic) NSString *lastImgSrc;
@property (nonatomic) NSInteger internalVolume;

@end

@implementation PlaybackController

// MARK: - Class Methods

+ (void)setPlayOnStart:(BOOL)play {
    playOnStart = play;

}

+ (BOOL)playOnStart {
    return playOnStart;
}

// MARK: - Lifecycle

- (instancetype)init {
    if ((self = [super init])) {
        NSLog(@"PlaybackController: init");
        _internalVolume = 100;
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
    [_progressUpdateTimer invalidate];
}

- (void)setup {
    NSLog(@"PlaybackController: setup called");
    
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    
    // Observe audio stream state changes
    [center addObserver:self
               selector:@selector(playbackStateChanged:)
                   name:ASStatusChangedNotification
                 object:nil];
    
    // Observe when a new song starts
    [center addObserver:self
               selector:@selector(songPlayed:)
                   name:@"StationDidPlaySongNotification"
                 object:nil];
    
    // Observe Pandora API responses
    [center addObserver:self
               selector:@selector(handlePandoraResponse:)
                   name:@"PandoraDidRateSongNotification"
                 object:nil];
    
    [center addObserver:self
               selector:@selector(handlePandoraResponse:)
                   name:@"PandoraDidDeleteFeedbackNotification"
                 object:nil];
    
    [center addObserver:self
               selector:@selector(handlePandoraResponse:)
                   name:@"PandoraDidTireSongNotification"
                 object:nil];
    
    // Observe app lifecycle for progress timer management
    [center addObserver:self
               selector:@selector(stopUpdatingProgress)
                   name:NSApplicationDidHideNotification
                 object:NSApp];
    
    [center addObserver:self
               selector:@selector(startUpdatingProgress)
                   name:NSApplicationDidUnhideNotification
                 object:NSApp];
    
    // Screensaver and screen lock notifications
    NSDistributedNotificationCenter *distCenter = [NSDistributedNotificationCenter defaultCenter];
    
    [distCenter addObserver:self
                   selector:@selector(pauseOnScreensaverStart:)
                       name:@"com.apple.screensaver.didstart"
                     object:nil];
    
    [distCenter addObserver:self
                   selector:@selector(playOnScreensaverStop:)
                       name:@"com.apple.screensaver.didstop"
                     object:nil];
    
    [distCenter addObserver:self
                   selector:@selector(pauseOnScreenLock:)
                       name:@"com.apple.screenIsLocked"
                     object:nil];
    
    [distCenter addObserver:self
                   selector:@selector(playOnScreenUnlock:)
                       name:@"com.apple.screenIsUnlocked"
                     object:nil];
    
    // Set up media key handling
    [self setupMediaKeys];
    
    NSLog(@"PlaybackController: setup complete");
}

- (void)setupMediaKeys {
    // Use MPRemoteCommandCenter for system media controls
    // This is the modern, built-in macOS API for media key handling
    _remoteCommandCenter = [MPRemoteCommandCenter sharedCommandCenter];
    
    BOOL enabled = PREF_KEY_BOOL(PLEASE_BIND_MEDIA);
    
    // Remove all existing handlers first to ensure clean state
    // This allows other apps to receive media key events when disabled
    [_remoteCommandCenter.playCommand removeTarget:self];
    [_remoteCommandCenter.pauseCommand removeTarget:self];
    [_remoteCommandCenter.nextTrackCommand removeTarget:self];
    [_remoteCommandCenter.togglePlayPauseCommand removeTarget:self];
    [_remoteCommandCenter.likeCommand removeTarget:self];
    [_remoteCommandCenter.dislikeCommand removeTarget:self];
    
    if (!enabled) {
        NSLog(@"Media keys disabled - handlers removed");
        return;
    }
    
    // Add handlers when enabled
    [_remoteCommandCenter.playCommand addTarget:self action:@selector(handlePlayCommand:)];
    [_remoteCommandCenter.pauseCommand addTarget:self action:@selector(handlePauseCommand:)];
    [_remoteCommandCenter.nextTrackCommand addTarget:self action:@selector(handleNextCommand:)];
    [_remoteCommandCenter.togglePlayPauseCommand addTarget:self action:@selector(handleTogglePlayPauseCommand:)];
    [_remoteCommandCenter.likeCommand addTarget:self action:@selector(handleLikeCommand:)];
    [_remoteCommandCenter.dislikeCommand addTarget:self action:@selector(handleDislikeCommand:)];
    
    NSLog(@"Media keys enabled via MPRemoteCommandCenter");
}

// MARK: - Media Command Handlers

- (MPRemoteCommandHandlerStatus)handlePlayCommand:(MPRemoteCommandEvent *)event {
    return [self play] ? MPRemoteCommandHandlerStatusSuccess : MPRemoteCommandHandlerStatusCommandFailed;
}

- (MPRemoteCommandHandlerStatus)handlePauseCommand:(MPRemoteCommandEvent *)event {
    return [self pause] ? MPRemoteCommandHandlerStatusSuccess : MPRemoteCommandHandlerStatusCommandFailed;
}

- (MPRemoteCommandHandlerStatus)handleNextCommand:(MPRemoteCommandEvent *)event {
    [self next];
    return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus)handleTogglePlayPauseCommand:(MPRemoteCommandEvent *)event {
    [self playpause];
    return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus)handleLikeCommand:(MPRemoteCommandEvent *)event {
    [self likeCurrent];
    return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus)handleDislikeCommand:(MPRemoteCommandEvent *)event {
    [self dislikeCurrent];
    return MPRemoteCommandHandlerStatusSuccess;
}

- (void)prepareFirst {
    NSInteger saved = [[NSUserDefaults standardUserDefaults] integerForKey:@"hermes.volume"];
    if (saved == 0) {
        saved = 100;
    }
    [self setVolume:saved];
}

// MARK: - Pandora Access

- (Pandora *)pandora {
    id delegate = [NSApp delegate];
    if ([delegate respondsToSelector:@selector(pandora)]) {
        return [delegate pandora];
    }
    return nil;
}

// MARK: - State Directory

- (NSString *)stateDirectory:(NSString *)file {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *folder = [@"~/Library/Application Support/Hermes/" stringByExpandingTildeInPath];
    
    BOOL isDir;
    if (![fileManager fileExistsAtPath:folder isDirectory:&isDir]) {
        [fileManager createDirectoryAtPath:folder
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:nil];
    }
    
    return [folder stringByAppendingPathComponent:file];
}

// MARK: - Station Management

- (void)playStation:(Station *)station {
    if ([_playing stationId] == [station stationId]) {
        return;
    }
    
    if (_playing) {
        [_playing stop];
        [[ImageCache shared] cancel:[[_playing playingSong] art]];
    }
    
    _playing = station;
    
    if (station == nil) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:LAST_STATION_KEY];
        _lastImgSrc = nil;
        [self postStateChange];
        return;
    }
    
    [[NSUserDefaults standardUserDefaults] setObject:[station stationId]
                                              forKey:LAST_STATION_KEY];
    
    if (playOnStart) {
        [station play];
    } else {
        playOnStart = YES;
    }
    
    [_playing setVolume:_internalVolume / 100.0];
    [self postStateChange];
}

- (void)reset {
    [self playStation:nil];
    
    NSString *path = [self stateDirectory:@"station.savestate"];
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
}

- (BOOL)saveState {
    NSString *path = [self stateDirectory:@"station.savestate"];
    if (path == nil) {
        return NO;
    }
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [NSKeyedArchiver archiveRootObject:_playing toFile:path];
#pragma clang diagnostic pop
}

// MARK: - Playback Controls

- (BOOL)play {
    if ([_playing isPlaying]) {
        return NO;
    }
    
    [_playing play];
    [self postStateChange];
    return YES;
}

- (BOOL)pause {
    if ([_playing isPlaying]) {
        [_playing pause];
        [self postStateChange];
        return YES;
    }
    return NO;
}

- (void)stop {
    [_playing stop];
    [self postStateChange];
}

- (void)playpause {
    if ([_playing isPaused]) {
        [self play];
    } else {
        [self pause];
    }
}

- (void)next {
    if ([_playing playingSong] != nil) {
        [[ImageCache shared] cancel:[[_playing playingSong] art]];
    }
    [_playing next];
}

// MARK: - Song Rating

- (void)rate:(Song *)song as:(BOOL)liked {
    if (!song || [[song station] shared]) return;
    
    int rating = liked ? 1 : -1;
    
    // Toggle rating if already set
    if ([[song nrating] intValue] == rating) {
        rating = 0;
    }
    
    BOOL songIsPlaying = [_playing playingSong] == song;
    
    if (rating == -1) {
        [[self pandora] rateSong:song as:NO];
        if (songIsPlaying) {
            [self next];
        }
    } else if (rating == 0) {
        [[self pandora] deleteRating:song];
    } else if (rating == 1) {
        [[self pandora] rateSong:song as:YES];
    }
    
    [self postStateChange];
}

- (void)likeCurrent {
    Song *song = [_playing playingSong];
    if (song) {
        [self rate:song as:YES];
    }
}

- (void)dislikeCurrent {
    Song *song = [_playing playingSong];
    if (song) {
        [_playing clearSongList];
        [self rate:song as:NO];
    }
}

- (void)tiredOfCurrent {
    if (_playing == nil || [_playing playingSong] == nil) {
        return;
    }
    
    [[self pandora] tiredOfSong:[_playing playingSong]];
    [self next];
}

// MARK: - Volume Control

- (NSInteger)volume {
    return _internalVolume;
}

- (void)setVolume:(NSInteger)vol {
    if (vol < 0) vol = 0;
    if (vol > 100) vol = 100;
    
    _internalVolume = vol;
    [_playing setVolume:vol / 100.0];
    
    [[NSUserDefaults standardUserDefaults] setInteger:vol forKey:@"hermes.volume"];
    [self postStateChange];
}

- (void)increaseVolume {
    [self setVolume:_internalVolume + 5];
}

- (void)decreaseVolume {
    [self setVolume:_internalVolume - 5];
}

// MARK: - Progress

- (double)currentProgress {
    double progress = 0;
    [_playing progress:&progress];
    return progress;
}

- (double)currentDuration {
    double duration = 0;
    [_playing duration:&duration];
    return duration;
}

- (void)startUpdatingProgress {
    if (_progressUpdateTimer != nil) {
        return;
    }
    
    _progressUpdateTimer = [NSTimer timerWithTimeInterval:1.0
                                                   target:self
                                                 selector:@selector(updateProgress:)
                                                 userInfo:nil
                                                  repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:_progressUpdateTimer forMode:NSRunLoopCommonModes];
}

- (void)stopUpdatingProgress {
    [_progressUpdateTimer invalidate];
    _progressUpdateTimer = nil;
}

- (void)updateProgress:(NSTimer *)timer {
    double prog = self.currentProgress;
    double dur = self.currentDuration;
    
    // Post progress notification
    [[NSNotificationCenter defaultCenter] postNotificationName:PlaybackProgressDidChangeNotification
                                                        object:self
                                                      userInfo:@{
        @"progress": @(prog),
        @"duration": @(dur)
    }];
    
    // Handle scrobbling
    if (!_scrobbleSent && dur > 30 && (prog * 2 > dur || prog > 4 * 60)) {
        _scrobbleSent = YES;
        // Scrobbling handled by Scrobbler class observing notifications
    }
}

// MARK: - Notification Handlers

- (void)playbackStateChanged:(NSNotification *)notification {
    BOOL currentlyPlaying = [_playing isPlaying];
    BOOL currentlyPaused = [_playing isPaused];
    
    NSLog(@"PlaybackController: playbackStateChanged - isPlaying=%d, isPaused=%d",
          currentlyPlaying, currentlyPaused);
    
    if (currentlyPlaying) {
        [self startUpdatingProgress];
    } else {
        [self stopUpdatingProgress];
    }
    
    [self postStateChange];
    [self updateNowPlayingInfo];
}

- (void)songPlayed:(NSNotification *)notification {
    Song *song = [_playing playingSong];
    if (!song) return;
    
    NSLog(@"PlaybackController: songPlayed - %@ by %@", song.title, song.artist);
    
    song.playDate = [NSDate date];
    _scrobbleSent = NO;
    
    // Load album art
    [self loadArtForSong:song];
    
    // Post song change notification
    [self postSongChange];
    [self updateNowPlayingInfo];
}

- (void)loadArtForSong:(Song *)song {
    if ([song art] == _lastImgSrc) {
        return; // Already loaded
    }
    
    _lastImgSrc = [song art];
    _lastImg = nil;
    _artImage = nil;
    
    if ([song art] == nil || [[song art] isEqual:@""]) {
        [self postArtLoaded];
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    [[ImageCache shared] loadImageURL:[song art] callback:^(NSData *data) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        strongSelf->_lastImg = data;
        if (data) {
            strongSelf->_artImage = [[NSImage alloc] initWithData:data];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [strongSelf postArtLoaded];
            [strongSelf updateNowPlayingInfo];
        });
    }];
}

- (void)handlePandoraResponse:(NSNotification *)notification {
    [self postStateChange];
}

// MARK: - Screensaver/Lock Handlers

- (void)pauseOnScreensaverStart:(NSNotification *)notification {
    if (!PREF_KEY_BOOL(PAUSE_ON_SCREENSAVER_START)) return;
    
    if ([self pause]) {
        self.pausedByScreensaver = YES;
    }
}

- (void)playOnScreensaverStop:(NSNotification *)notification {
    if (!PREF_KEY_BOOL(PLAY_ON_SCREENSAVER_STOP)) return;
    
    if (self.pausedByScreensaver) {
        [self play];
    }
    self.pausedByScreensaver = NO;
}

- (void)pauseOnScreenLock:(NSNotification *)notification {
    if (!PREF_KEY_BOOL(PAUSE_ON_SCREEN_LOCK)) return;
    
    if ([self pause]) {
        self.pausedByScreenLock = YES;
    }
}

- (void)playOnScreenUnlock:(NSNotification *)notification {
    if (!PREF_KEY_BOOL(PLAY_ON_SCREEN_UNLOCK)) return;
    
    if (self.pausedByScreenLock) {
        [self play];
    }
    self.pausedByScreenLock = NO;
}

// MARK: - Now Playing Info

- (void)updateNowPlayingInfo {
    if (![MPNowPlayingInfoCenter class]) return;
    
    Song *song = [_playing playingSong];
    if (!song) {
        [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:nil];
        return;
    }
    
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    
    info[MPMediaItemPropertyTitle] = song.title ?: @"";
    info[MPMediaItemPropertyArtist] = song.artist ?: @"";
    info[MPMediaItemPropertyAlbumTitle] = song.album ?: @"";
    
    double duration = self.currentDuration;
    if (duration > 0) {
        info[MPMediaItemPropertyPlaybackDuration] = @(duration);
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = @(self.currentProgress);
    }
    
    info[MPNowPlayingInfoPropertyPlaybackRate] = @([_playing isPlaying] ? 1.0 : 0.0);
    
    if (_artImage) {
        MPMediaItemArtwork *artwork = [[MPMediaItemArtwork alloc]
            initWithBoundsSize:_artImage.size
            requestHandler:^NSImage *(CGSize size) {
                return self->_artImage;
            }];
        info[MPMediaItemPropertyArtwork] = artwork;
    }
    
    [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:info];
}

// MARK: - Notification Posting

- (void)postStateChange {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:PlaybackStateDidChangeNotification
                                                            object:self];
    });
}

- (void)postSongChange {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:PlaybackSongDidChangeNotification
                                                            object:self];
    });
}

- (void)postArtLoaded {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:PlaybackArtDidLoadNotification
                                                            object:self];
    });
}

@end
