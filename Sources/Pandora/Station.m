
#import "Pandora/Station.h"
#import "Pandora/Pandora.h"
#import "HermesConstants.h"
#import "Hermes-Swift.h"
// #import "StationsController.h" // TODO: Update AppleScript support for SwiftUI

@implementation Station

- (id) init {
  if (!(self = [super init])) return nil;

  songs = [NSMutableArray arrayWithCapacity:10];

  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(fetchMoreSongs:)
             name:ASRunningOutOfSongs
           object:self];
  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(fetchMoreSongs:)
             name:ASNoSongsLeft
           object:self];

  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(configureNewStream:)
             name:ASCreatedNewStream
           object:self];

  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(newSongPlaying:)
             name:ASNewSongPlaying
           object:self];

  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(attemptingNewSong:)
             name:ASAttemptingNewSong
           object:self];

  return self;
}

- (id) initWithCoder:(NSCoder *)aDecoder {
  if ((self = [self init])) {
    [self setStationId:[aDecoder decodeObjectForKey:@"stationId"]];
    [self setName:[aDecoder decodeObjectForKey:@"name"]];
    [self setVolume:[aDecoder decodeFloatForKey:@"volume"]];
    [self setCreated:[aDecoder decodeInt32ForKey:@"created"]];
    [self setToken:[aDecoder decodeObjectForKey:@"token"]];
    [self setShared:[aDecoder decodeBoolForKey:@"shared"]];
    [self setAllowAddMusic:[aDecoder decodeBoolForKey:@"allowAddMusic"]];
    [self setAllowRename:[aDecoder decodeBoolForKey:@"allowRename"]];
    [self setArtUrl:[aDecoder decodeObjectForKey:@"artUrl"]];
    [self setGenres:[aDecoder decodeObjectForKey:@"genres"]];
    lastKnownSeekTime = [aDecoder decodeFloatForKey:@"lastKnownSeekTime"];
    [songs addObject:[aDecoder decodeObjectForKey:@"playing"]];
    [songs addObjectsFromArray:[aDecoder decodeObjectForKey:@"songs"]];
    [urls addObject:[aDecoder decodeObjectForKey:@"playingURL"]];
    [urls addObjectsFromArray:[aDecoder decodeObjectForKey:@"urls"]];
    if ([songs count] != [urls count]) {
      [songs removeAllObjects];
      [urls removeAllObjects];
    }
    [Station addStation:self];
  }
  return self;
}

- (void) encodeWithCoder:(NSCoder *)aCoder {
  [aCoder encodeObject:_stationId forKey:@"stationId"];
  [aCoder encodeObject:_name forKey:@"name"];
  [aCoder encodeObject:_playingSong forKey:@"playing"];
  double seek = -1;
  if (_playingSong) {
    [stream progress:&seek];
  }
  [aCoder encodeFloat:seek forKey:@"lastKnownSeekTime"];
  [aCoder encodeFloat:volume forKey:@"volume"];
  [aCoder encodeInt32:(int32_t)_created forKey:@"created"]; // XXX truncated?
  [aCoder encodeObject:songs forKey:@"songs"];
  [aCoder encodeObject:urls forKey:@"urls"];
  [aCoder encodeObject:[self playing] forKey:@"playingURL"];
  [aCoder encodeObject:_token forKey:@"token"];
  [aCoder encodeBool:_shared forKey:@"shared"];
  [aCoder encodeBool:_allowAddMusic forKey:@"allowAddMusic"];
  [aCoder encodeBool:_allowRename forKey:@"allowRename"];
  [aCoder encodeObject:_artUrl forKey:@"artUrl"];
  [aCoder encodeObject:_genres forKey:@"genres"];
}

- (void) dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:nil];
}

- (BOOL) isEqual:(id)object {
  return [_stationId isEqual:[object stationId]];
}

- (void) attemptingNewSong:(NSNotification*) notification {
    _playingSong = songs[0];
    [songs removeObjectAtIndex:0];
}

- (void) fetchMoreSongs:(NSNotification*) notification {
  shouldPlaySongOnFetch = YES;
  [radio fetchPlaylistForStation:self];
}

- (void) setRadio:(Pandora *)pandora {
  @synchronized(radio) {
    if (radio != nil) {
      [[NSNotificationCenter defaultCenter] removeObserver:self
                                                      name:nil
                                                    object:radio];
    }
    radio = pandora;

    NSString *n = [NSString stringWithFormat:@"hermes.fragment-fetched.%@", _token];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(songsLoaded:)
                                                 name:n
                                               object:nil];
  }
}

- (void) songsLoaded: (NSNotification*)not {
  NSArray *more = [not userInfo][@"songs"];
  NSMutableArray *qualities = [[NSMutableArray alloc] init];
  if (more == nil) return;

  for (Song *s in more) {
    NSURL *url = nil;
    NSString *selectedQuality = @"unknown";
    
    // Select URL based on user preference
    switch (PREF_KEY_INT(DESIRED_QUALITY)) {
      case QUALITY_HIGH:
        if (s.highUrl) {
          url = [NSURL URLWithString:s.highUrl];
          selectedQuality = @"high";
        }
        break;
      case QUALITY_LOW:
        if (s.lowUrl) {
          url = [NSURL URLWithString:s.lowUrl];
          selectedQuality = @"low";
        }
        break;
      case QUALITY_MED:
      default:
        if (s.medUrl) {
          url = [NSURL URLWithString:s.medUrl];
          selectedQuality = @"med";
        }
        break;
    }
    
    // Fallback to available quality if preferred isn't available
    if (!url) {
      if (s.medUrl) {
        url = [NSURL URLWithString:s.medUrl];
        selectedQuality = @"med (fallback)";
      } else if (s.highUrl) {
        url = [NSURL URLWithString:s.highUrl];
        selectedQuality = @"high (fallback)";
      } else if (s.lowUrl) {
        url = [NSURL URLWithString:s.lowUrl];
        selectedQuality = @"low (fallback)";
      }
    }
    
    if (url) {
      [urls addObject:url];
      [songs addObject:s];
      [qualities addObject:selectedQuality];
    } else {
      NSLog(@"Warning: No valid audio URL found for song: %@ - %@", s.artist, s.title);
    }
  }
  
  if (shouldPlaySongOnFetch && [songs count] > 0) {
    [self play];
  }
  shouldPlaySongOnFetch = NO;
  
  if ([qualities count] > 0) {
    NSLogd(@"Loaded %lu songs with qualities: %@", (unsigned long)[qualities count], [qualities componentsJoinedByString:@", "]);
  }
}

- (void) configureNewStream:(NSNotification*) notification {
  assert(stream == [notification userInfo][@"stream"]);
  [stream setBufferInfinite:TRUE];
  [stream setTimeoutInterval:15];

  if (PREF_KEY_BOOL(PROXY_AUDIO)) {
    switch ([PREF_KEY_VALUE(ENABLED_PROXY) intValue]) {
      case PROXY_HTTP:
        [stream setHTTPProxy:PREF_KEY_VALUE(PROXY_HTTP_HOST)
                        port:[PREF_KEY_VALUE(PROXY_HTTP_PORT) intValue]];
        break;
      case PROXY_SOCKS:
        [stream setSOCKSProxy:PREF_KEY_VALUE(PROXY_SOCKS_HOST)
                         port:[PREF_KEY_VALUE(PROXY_SOCKS_PORT) intValue]];
        break;
      default:
        break;
    }
  }
  
  // Apply track gain normalization if available
  if (_playingSong && _playingSong.trackGain) {
    [self applyTrackGain:_playingSong.trackGain];
  }
}

- (void) applyTrackGain:(NSString*)gainString {
  // Track gain is in dB format (e.g., "10.09", "-2.5")
  // Convert to linear scale and adjust volume
  double gainDB = [gainString doubleValue];
  
  // Convert dB to linear scale: linear = 10^(dB/20)
  // Clamp to reasonable range to avoid extreme values
  gainDB = MAX(-15.0, MIN(15.0, gainDB));
  double gainLinear = pow(10.0, gainDB / 20.0);
  
  // Apply gain adjustment to current volume
  // Volume is already set, so we adjust it by the gain factor
  double adjustedVolume = volume * gainLinear;
  adjustedVolume = MAX(0.0, MIN(1.0, adjustedVolume)); // Clamp to 0-1 range
  
  NSLogd(@"Applying track gain: %@ dB (%.2fx linear) to volume %.2f -> %.2f", 
         gainString, gainLinear, volume, adjustedVolume);
  
  [stream setVolume:adjustedVolume];
}

- (void) newSongPlaying:(NSNotification*) notification {
  assert([songs count] == [urls count]);
  [[NSNotificationCenter defaultCenter]
        postNotificationName:@"StationDidPlaySongNotification"
                      object:self
                    userInfo:nil];
}

- (NSString*) streamNetworkError {
  if ([stream errorCode] == AS_NETWORK_CONNECTION_FAILED) {
    return [[stream networkError] localizedDescription];
  }
  return [AudioStreamer stringForErrorCode:[stream errorCode]];
}

- (NSScriptObjectSpecifier *) objectSpecifier {
  // TODO: Update AppleScript support for SwiftUI architecture
  // This requires accessing stations from AppState instead of StationsController
  return nil;
  
  /* Original code - requires StationsController
  HermesAppDelegate *delegate = HMSAppDelegate;
  StationsController *stationsc = [delegate stations];
  int index = [stationsc stationIndex:self];

  NSScriptClassDescription *containerClassDesc =
      [NSScriptClassDescription classDescriptionForClass:[NSApp class]];

  return [[NSIndexSpecifier alloc]
           initWithContainerClassDescription:containerClassDesc
           containerSpecifier:nil key:@"stations" index:index];
  */
}

- (void) clearSongList {
  [songs removeAllObjects];
  [super clearSongList];
}

static NSMutableDictionary *stations = nil;

+ (Station*) stationForToken:(NSString*)stationId{
  if (stations == nil)
    return nil;
  return stations[stationId];
}

+ (void) addStation:(Station*) s {
  if (stations == nil) {
    stations = [NSMutableDictionary dictionary];
  }
  stations[[s stationId]] = s;
}

+ (void) removeStation:(Station*) s {
  if (stations == nil)
    return;
  [stations removeObjectForKey:[s stationId]];
}

@end
