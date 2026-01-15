//
//  HermesConstants.h
//  Hermes
//
//  Shared constants and macros for Hermes app
//

#import <Foundation/Foundation.h>

// User Defaults access macros
#define PREFERENCES                  [NSUserDefaults standardUserDefaults]
#define PREF_KEY_VALUE(x)            [PREFERENCES valueForKey:(x)]
#define PREF_KEY_BOOL(x)             [PREFERENCES boolForKey:(x)]
#define PREF_KEY_INT(x)              [PREFERENCES integerForKey:(x)]
#define PREF_KEY_SET_BOOL(x, y)      [PREFERENCES setBool:y forKey:x]
#define PREF_KEY_SET_INT(x, y)       [PREFERENCES setInteger:y forKey:x]

// Proxy settings keys
#define ENABLED_PROXY                @"enabledProxy"
#define PROXY_HTTP_HOST              @"httpProxyHost"
#define PROXY_HTTP_PORT              @"httpProxyPort"
#define PROXY_SOCKS_HOST             @"socksProxyHost"
#define PROXY_SOCKS_PORT             @"socksProxyPort"
#define PROXY_AUDIO                  @"proxyAudio"

// Proxy types
#define PROXY_SYSTEM 0
#define PROXY_HTTP   1
#define PROXY_SOCKS  2

// Audio quality settings
#define DESIRED_QUALITY              @"audioQuality"
#define QUALITY_HIGH 0
#define QUALITY_MED  1
#define QUALITY_LOW  2

// Last.fm scrobbling settings
#define PLEASE_SCROBBLE              @"pleaseScrobble"
#define PLEASE_SCROBBLE_LIKES        @"pleaseScrobbleLikes"
#define ONLY_SCROBBLE_LIKED          @"onlyScrobbleLiked"

// Station sorting settings
#define SORT_STATIONS                @"sortStations"
#define SORT_DATE_ASC 0
#define SORT_DATE_DSC 1
#define SORT_NAME_ASC 2
#define SORT_NAME_DSC 3

// Playback settings
#define LAST_STATION_KEY             @"lastStation"
#define PAUSE_ON_SCREENSAVER_START   @"pauseOnScreensaverStart"
#define PLAY_ON_SCREENSAVER_STOP     @"playOnScreensaverStop"
#define PAUSE_ON_SCREEN_LOCK         @"pauseOnScreenLock"
#define PLAY_ON_SCREEN_UNLOCK        @"playOnScreenUnlock"
#define PLAY_AUTOMATICALLY_ON_LAUNCH @"playAutomaticallyOnLaunch"
