//
//  AppleScript.m
//  Hermes
//
//  Created by Alex Crichton on 11/19/11.
//

#import "AppleScript.h"
#import "PlaybackController.h"
#import "StationsController.h"

NSInteger savedVolume = 0;

@implementation PlayCommand
- (id) performDefaultImplementation {
  PlaybackController *playback = [HMSAppDelegate playback];
  return @([playback play]);
}
@end

@implementation PauseCommand
- (id) performDefaultImplementation {
  PlaybackController *playback = [HMSAppDelegate playback];
  return @([playback pause]);
}
@end

@implementation PlayPauseCommand
- (id) performDefaultImplementation {
  PlaybackController *playback = [HMSAppDelegate playback];
  [playback playpause];
  return self;
}
@end

@implementation SkipCommand
- (id) performDefaultImplementation {
  PlaybackController *playback = [HMSAppDelegate playback];
  [playback next];
  return self;
}
@end

@implementation ThumbsUpCommand
- (id) performDefaultImplementation {
  PlaybackController *playback = [HMSAppDelegate playback];
  [playback likeCurrent];
  return self;
}
@end

@implementation ThumbsDownCommand
- (id) performDefaultImplementation {
  PlaybackController *playback = [HMSAppDelegate playback];
  [playback dislikeCurrent];
  return self;
}
@end

@implementation RaiseVolumeCommand
- (id) performDefaultImplementation {
  PlaybackController *playback = [HMSAppDelegate playback];
  NSInteger vol = [playback volume];
  [playback setVolume:vol + 7];
  NSLogd(@"Raised volume to: %ld", (long)[playback volume]);
  return self;
}
@end

@implementation LowerVolumeCommand
- (id) performDefaultImplementation {
  PlaybackController *playback = [HMSAppDelegate playback];
  NSInteger vol = [playback volume];
  [playback setVolume:vol - 7];
  NSLogd(@"Lowered volume to: %ld", (long)[playback volume]);
  return self;
}
@end

@implementation FullVolumeCommand
- (id) performDefaultImplementation {
  PlaybackController *playback = [HMSAppDelegate playback];
  [playback setVolume:100];
  NSLogd(@"Changed volume to: %ld", (long)[playback volume]);
  return self;
}
@end

@implementation MuteCommand
- (id) performDefaultImplementation {
  PlaybackController *playback = [HMSAppDelegate playback];
  savedVolume = [playback volume];
  [playback setVolume:0];
  NSLogd(@"Changed volume to: %ld", (long)[playback volume]);
  return self;
}
@end

@implementation UnmuteCommand
- (id) performDefaultImplementation {
  PlaybackController *playback = [HMSAppDelegate playback];
  [playback setVolume:savedVolume];
  NSLogd(@"Changed volume to: %ld", (long)[playback volume]);
  return self;
}
@end

@implementation TiredCommand
- (id) performDefaultImplementation {
  PlaybackController *playback = [HMSAppDelegate playback];
  [playback tiredOfCurrent];
  return self;
}
@end

@implementation NSApplication (HermesScripting)

- (NSNumber*) volume {
  PlaybackController *playback = [HMSAppDelegate playback];
  return @([playback volume]);
}

- (void) setVolume: (NSNumber*) vol {
  PlaybackController *playback = [HMSAppDelegate playback];
  [playback setVolume:[vol integerValue]];
}

- (int) playbackState {
  PlaybackController *playback = [HMSAppDelegate playback];
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
  PlaybackController *playback = [HMSAppDelegate playback];
  [[playback playing] progress:&progress];
  return @(progress);
}

- (NSNumber *) currentSongDuration {
  double duration;
  PlaybackController *playback = [HMSAppDelegate playback];
  [[playback playing] duration:&duration];
  return @(duration);
}

- (void) setPlaybackState: (int) state {
  PlaybackController *playback = [HMSAppDelegate playback];
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
  PlaybackController *playback = [HMSAppDelegate playback];
  return [playback playing];
}

- (void) setCurrentStation:(Station *)station {
  HermesAppDelegate *delegate = HMSAppDelegate;
  PlaybackController *playback = [delegate playback];
  [playback playStation:station];
  StationsController *stations = [delegate stations];
  [stations refreshList:self];
}

- (NSArray*) stations {
  HermesAppDelegate *delegate = HMSAppDelegate;
  return [[delegate pandora] stations];
}

- (Song*) currentSong {
  PlaybackController *playback = [HMSAppDelegate playback];
  return [[playback playing] playingSong];
}

@end
