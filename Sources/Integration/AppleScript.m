//
//  AppleScript.m
//  Hermes
//
//  Created by Alex Crichton on 11/19/11.
//

#import "AppleScript.h"
#import "PlaybackController.h"
#import "Pandora/Pandora.h"
#import "Hermes-Swift.h" // For MinimalAppDelegate
// #import "StationsController.h" // TODO: Update AppleScript for SwiftUI architecture

NSInteger savedVolume = 0;

// Helper to get PlaybackController from MinimalAppDelegate
static PlaybackController* GetPlaybackController(void) {
    MinimalAppDelegate *delegate = [MinimalAppDelegate shared];
    return [delegate playbackController];
}

@implementation PlayCommand
- (id) performDefaultImplementation {
  PlaybackController *playback = GetPlaybackController();
  return @([playback play]);
}
@end

@implementation PauseCommand
- (id) performDefaultImplementation {
  PlaybackController *playback = GetPlaybackController();
  return @([playback pause]);
}
@end

@implementation PlayPauseCommand
- (id) performDefaultImplementation {
  PlaybackController *playback = GetPlaybackController();
  [playback playpause];
  return self;
}
@end

@implementation SkipCommand
- (id) performDefaultImplementation {
  PlaybackController *playback = GetPlaybackController();
  [playback next];
  return self;
}
@end

@implementation ThumbsUpCommand
- (id) performDefaultImplementation {
  PlaybackController *playback = GetPlaybackController();
  [playback likeCurrent];
  return self;
}
@end

@implementation ThumbsDownCommand
- (id) performDefaultImplementation {
  PlaybackController *playback = GetPlaybackController();
  [playback dislikeCurrent];
  return self;
}
@end

@implementation RaiseVolumeCommand
- (id) performDefaultImplementation {
  PlaybackController *playback = GetPlaybackController();
  NSInteger vol = [playback volume];
  [playback setVolume:vol + 7];
  NSLogd(@"Raised volume to: %ld", (long)[playback volume]);
  return self;
}
@end

@implementation LowerVolumeCommand
- (id) performDefaultImplementation {
  PlaybackController *playback = GetPlaybackController();
  NSInteger vol = [playback volume];
  [playback setVolume:vol - 7];
  NSLogd(@"Lowered volume to: %ld", (long)[playback volume]);
  return self;
}
@end

@implementation FullVolumeCommand
- (id) performDefaultImplementation {
  PlaybackController *playback = GetPlaybackController();
  [playback setVolume:100];
  NSLogd(@"Changed volume to: %ld", (long)[playback volume]);
  return self;
}
@end

@implementation MuteCommand
- (id) performDefaultImplementation {
  PlaybackController *playback = GetPlaybackController();
  savedVolume = [playback volume];
  [playback setVolume:0];
  NSLogd(@"Changed volume to: %ld", (long)[playback volume]);
  return self;
}
@end

@implementation UnmuteCommand
- (id) performDefaultImplementation {
  PlaybackController *playback = GetPlaybackController();
  [playback setVolume:savedVolume];
  NSLogd(@"Changed volume to: %ld", (long)[playback volume]);
  return self;
}
@end

@implementation TiredCommand
- (id) performDefaultImplementation {
  PlaybackController *playback = GetPlaybackController();
  [playback tiredOfCurrent];
  return self;
}
@end

@implementation NSApplication (HermesScripting)

- (NSNumber*) volume {
  PlaybackController *playback = GetPlaybackController();
  return @([playback volume]);
}

- (void) setVolume: (NSNumber*) vol {
  PlaybackController *playback = GetPlaybackController();
  [playback setVolume:[vol integerValue]];
}

- (int) playbackState {
  PlaybackController *playback = GetPlaybackController();
  Station *playing = [playback playing];
  if (playing == nil) {
    return PlaybackStateStopped;
  } else if ([playing isPaused]) {
    return PlaybackStatePaused;
  }
  return PlaybackStatePlaying;
}

- (NSNumber *) playbackPosition {
  double progress;
  PlaybackController *playback = GetPlaybackController();
  [[playback playing] progress:&progress];
  return @(progress);
}

- (NSNumber *) currentSongDuration {
  double duration;
  PlaybackController *playback = GetPlaybackController();
  [[playback playing] duration:&duration];
  return @(duration);
}

- (void) setPlaybackState: (int) state {
  PlaybackController *playback = GetPlaybackController();
  switch (state) {
    case PlaybackStateStopped:
    case PlaybackStatePaused:
      [playback pause];
      break;

    case PlaybackStatePlaying:
      [playback play];
      break;

    default:
      NSLog(@"Invalid playback state: %d", state);
  }
}

- (Station*) currentStation {
  PlaybackController *playback = GetPlaybackController();
  return [playback playing];
}

- (void) setCurrentStation:(Station *)station {
  // TODO: Update AppleScript support for SwiftUI architecture
  // This requires accessing PlaybackController through MinimalAppDelegate
  // and refreshing stations through AppState
  
  /* Original code - requires HMSAppDelegate and StationsController
  HermesAppDelegate *delegate = HMSAppDelegate;
  PlaybackController *playback = [delegate playback];
  [playback playStation:station];
  StationsController *stations = [delegate stations];
  [stations refreshList:self];
  */
}

- (NSArray*) stations {
  // Access stations directly from Pandora
  id delegate = [NSApp delegate];
  if ([delegate respondsToSelector:@selector(pandora)]) {
    Pandora *pandora = [delegate performSelector:@selector(pandora)];
    return [pandora stations];
  }
  return @[];
}

- (Song*) currentSong {
  PlaybackController *playback = GetPlaybackController();
  return [[playback playing] playingSong];
}

@end
