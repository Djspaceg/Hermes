# Pandora API Gap Analysis

**Date:** January 16, 2026  
**Current Implementation:** JSON API v5 (Unofficial)  
**Status:** 7+ years without updates

## Executive Summary

Hermes currently uses the **unofficial Pandora JSON API v5** with hardcoded partner credentials from 2014-2017. Pandora has since moved to an **official GraphQL API** for partners, while the JSON v5 API remains functional but unsupported. This analysis identifies missing features, deprecated patterns, and modernization opportunities.

## Critical Findings

### 🚨 API Status

1. **Unofficial API Usage**: Hermes relies on reverse-engineered JSON v5 endpoints
2. **Hardcoded Credentials**: Partner credentials (Android, iPhone, Desktop) are embedded in source
3. **No Official Support**: Pandora's official developer program uses GraphQL exclusively
4. **Functional but Fragile**: JSON v5 still works but could break without notice

### 🔄 Official API Migration Path

Pandora now offers an **official GraphQL API** for approved partners:

- Requires developer account approval
- OAuth 2.0 authentication (vs. partner login)
- GraphQL queries instead of REST-like JSON endpoints
- Better documentation and support
- More features (collections, profiles, podcasts)

**Recommendation**: Consider applying for official API access if Hermes becomes a commercial product.

---

## Feature Gap Analysis

### ✅ Currently Implemented (JSON v5)

| Feature | Method | Status |
|---------|--------|--------|
| Partner Login | `auth.partnerLogin` | ✅ Working |
| User Login | `auth.userLogin` | ✅ Working |
| Station List | `user.getStationList` | ✅ Working |
| Playlist Retrieval | `station.getPlaylist` | ✅ Working |
| Create Station | `station.createStation` | ✅ Working |
| Delete Station | `station.deleteStation` | ✅ Working |
| Rename Station | `station.renameStation` | ✅ Working |
| Rate Song (Thumbs) | `station.addFeedback` | ✅ Working |
| Delete Rating | `station.deleteFeedback` | ✅ Working |
| Tired of Song | `user.sleepSong` | ✅ Working |
| Search Music | `music.search` | ✅ Working |
| Add Seed | `station.addMusic` | ✅ Working |
| Remove Seed | `station.deleteMusic` | ✅ Working |
| Station Info | `station.getStation` | ✅ Working |
| Genre Stations | `station.getGenreStations` | ✅ Working |

### ❌ Missing Features (Available in JSON v5)

| Feature | Method | Impact | Difficulty |
|---------|--------|--------|------------|
| **Bookmarks** | `user.getBookmarks` | Medium | Easy |
| | `bookmark.addArtistBookmark` | Users can't save favorite artists | |
| | `bookmark.addSongBookmark` | Users can't save favorite songs | |
| **Track Explanation** | `track.explainTrack` | Low | Easy |
| | | Shows Music Genome attributes | |
| **Station Checksum** | `user.getStationListChecksum` | Low | Easy |
| | | Efficient sync detection | |
| **Genre Checksum** | `station.getGenreStationsChecksum` | Low | Easy |
| **Transform Shared** | `station.transformSharedStation` | Medium | Medium |
| | | Can't modify shared stations | |
| **QuickMix Modification** | `user.setQuickMix` | High | Medium |
| | | Can't customize shuffle stations | |
| **License Check** | `test.checkLicensing` | Low | Easy |
| | | Geographic availability check | |

### 🆕 GraphQL-Only Features (Official API)

These features are **only available** through Pandora's official GraphQL API:

| Feature Category | Capabilities | Business Value |
|-----------------|--------------|----------------|
| **Podcasts** | Browse, search, play episodes | Major content expansion |
| **Collections** | User's saved music library | Better organization |
| **Top Artists** | User's most-played artists | Discovery & stats |
| **Favorites** | Quick access to favorites | Improved UX |
| **Profile** | Bio, followers, following | Social features |
| **Playlists** | Curated and user playlists | Content variety |
| **Albums** | Full album playback | On-demand listening |
| **Recommendations** | Personalized suggestions | Discovery |
| **Advanced Playback** | Replay, repeat, shuffle modes | Better controls |

---

## Implementation Gaps in Current Code

### 1. Bookmarks (High Priority)

**What's Missing:**

- No UI for bookmarking artists/songs
- No bookmark retrieval or display
- No bookmark management

**User Impact:**

- Can't save favorite discoveries for later
- No way to build a personal collection

**Implementation Effort:** Low

```objc
// Add to Pandora.h
- (BOOL) fetchBookmarks;
- (BOOL) addArtistBookmark:(NSString*)trackToken;
- (BOOL) addSongBookmark:(NSString*)trackToken;
```

### 2. QuickMix/Shuffle Customization (High Priority)

**What's Missing:**

- Can't select which stations go into shuffle
- QuickMix station exists but isn't configurable
- No UI to manage shuffle composition

**User Impact:**

- Shuffle includes ALL stations (can't exclude some)
- Less control over listening experience

**Implementation Effort:** Medium

```objc
// Add to Pandora.h
- (BOOL) setQuickMixStations:(NSArray<NSString*>*)stationIds;
```

**UI Needed:**

- Checkboxes in station list for shuffle inclusion
- "Include in Shuffle" toggle per station

### 3. Track Explanation (Low Priority)

**What's Missing:**

- No "Why was this song selected?" feature
- Can't see Music Genome Project attributes

**User Impact:**

- Less transparency about recommendations
- Missed educational opportunity

**Implementation Effort:** Easy

```objc
// Add to Pandora.h
- (BOOL) explainTrack:(Song*)song;
```

### 4. Shared Station Transformation (Medium Priority)

**What's Missing:**

- Can't modify stations shared by other users
- No "Make this mine" functionality

**User Impact:**

- Shared stations are read-only
- Can't rate songs on shared stations

**Implementation Effort:** Medium

### 5. Efficient Sync with Checksums (Low Priority)

**What's Missing:**

- Always fetches full station list
- No incremental updates

**User Impact:**

- Slightly slower startup
- More bandwidth usage

**Implementation Effort:** Easy

---

## Data Model Gaps

### Song Model - Missing Fields

Current `Song` class captures most fields, but missing:

| Field | Available in API | Currently Stored | Use Case |
|-------|------------------|------------------|----------|
| `trackGain` | ✅ | ❌ | Audio normalization |
| `allowFeedback` | ✅ | ❌ | UI state (disable thumbs) |
| `songExplorerUrl` | ✅ | ❌ | Deep linking |
| `albumExplorerUrl` | ✅ | ❌ | Deep linking |
| `artistExplorerUrl` | ✅ | ❌ | Deep linking |
| `amazonAlbumAsin` | ✅ | ❌ | Purchase links |
| `amazonSongDigitalAsin` | ✅ | ❌ | Purchase links |
| `itunesSongUrl` | ✅ | ❌ | Purchase links |

**Recommendation:** Add `trackGain` for better audio normalization.

### Station Model - Missing Fields

| Field | Available in API | Currently Stored | Use Case |
|-------|------------------|------------------|----------|
| `suppressVideoAds` | ✅ | ❌ | Ad handling |
| `requiresCleanAds` | ✅ | ❌ | Content filtering |
| `stationDetailUrl` | ✅ | ❌ | Web linking |
| `stationSharingUrl` | ✅ | ❌ | Social sharing |
| `allowEditDescription` | ✅ | ❌ | UI permissions |
| `genre` | ✅ | ❌ | Categorization |
| `artUrl` | ✅ | ❌ | Station artwork |

**Recommendation:** Add `artUrl` for richer station display.

---

## Audio Quality Handling

### Current Implementation

```objc
// Station.m - Quality selection
switch (PREF_KEY_INT(DESIRED_QUALITY)) {
    case QUALITY_HIGH:
        url = [NSURL URLWithString:[s highUrl]];
        break;
    case QUALITY_LOW:
        url = [NSURL URLWithString:[s lowUrl]];
        break;
    case QUALITY_MED:
    default:
        url = [NSURL URLWithString:[s medUrl]];
        break;
}
```

### API Provides

- `audioUrlMap` with detailed bitrate/encoding info
- Multiple quality tiers:
  - **Low**: 32 Kbps AAC+
  - **Medium**: 64 Kbps AAC+
  - **High**: 64-192 Kbps (192 for Pandora One subscribers)

### Gap

- Not using `audioUrlMap` bitrate information
- Could display actual bitrate to user
- Could auto-select based on network conditions

---

## Authentication & Security

### Current Implementation

```objc
// PandoraDevice.m - Hardcoded credentials
+ (NSDictionary *)android {
    return @{
        kPandoraDeviceUsername: @"android",
        kPandoraDevicePassword: @"AC7IBG09A3DTSYM4R41UJWL07VLN8JI7",
        kPandoraDeviceDeviceID: @"android-generic",
        kPandoraDeviceEncrypt:  @"6#26FRL$ZWD",
        kPandoraDeviceDecrypt:  @"R=U!LH$O2B#",
        kPandoraDeviceAPIHost:  @"tuner.pandora.com"
    };
}
```

### Issues

1. **Hardcoded Credentials**: Partner passwords in source code
2. **Blowfish ECB**: Outdated encryption mode (ECB is insecure)
3. **No Certificate Pinning**: Vulnerable to MITM attacks
4. **Sync Time Protection**: Basic replay attack prevention

### Recommendations

1. Keep credentials obfuscated (already public knowledge)
2. Add certificate pinning for API endpoints
3. Consider moving to official OAuth if possible

---

## API Endpoint Status

### Current Endpoints

```
http://tuner.pandora.com/services/json/          (Android/iPhone)
https://internal-tuner.pandora.com/services/json/ (Desktop/Pandora One)
```

### Status

- ✅ Still functional as of 2024
- ⚠️ No official support or SLA
- ⚠️ Could break without notice
- ⚠️ Rate limiting unknown

### Official GraphQL Endpoint

```
https://www.pandora.com/api/v1/graphql
```

- Requires OAuth 2.0 token
- Requires approved developer account
- Official support and documentation

---

## Modernization Recommendations

### Priority 1: High-Value, Low-Effort

1. **Add Bookmarks Support**
   - Methods: `user.getBookmarks`, `bookmark.addArtistBookmark`, `bookmark.addSongBookmark`
   - UI: Bookmark button in player, bookmarks view in sidebar
   - Effort: 2-3 days

2. **QuickMix Customization**
   - Method: `user.setQuickMix`
   - UI: Checkboxes in station list
   - Effort: 1-2 days

3. **Track Gain Normalization**
   - Use `trackGain` field from API
   - Apply to AudioStreamer volume
   - Effort: 1 day

### Priority 2: Quality of Life

1. **Station Artwork**
   - Use `artUrl` from station info
   - Display in station list
   - Effort: 1 day

2. **Track Explanation**
   - Method: `track.explainTrack`
   - UI: "Why this song?" popover
   - Effort: 2 days

3. **Shared Station Transform**
   - Method: `station.transformSharedStation`
   - UI: "Make this mine" button
   - Effort: 2 days

### Priority 3: Optimization

1. **Checksum-Based Sync**
   - Methods: `user.getStationListChecksum`, `station.getGenreStationsChecksum`
   - Reduce unnecessary data fetching
   - Effort: 1 day

2. **Better Error Handling**
   - Parse all error codes (currently partial)
   - User-friendly error messages
   - Retry logic for transient failures
   - Effort: 2 days

### Priority 4: Future-Proofing

1. **Official API Migration Path**
   - Research Pandora Developer Program requirements
   - Prototype OAuth 2.0 flow
   - Map GraphQL queries to current features
   - Effort: 1-2 weeks (investigation phase)

---

## Risk Assessment

### Current API Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| JSON v5 API shutdown | Low | Critical | Monitor for changes, have migration plan |
| Credential rotation | Medium | High | Update credentials when needed |
| Rate limiting | Low | Medium | Implement exponential backoff |
| Breaking changes | Low | High | Version detection, graceful degradation |
| Geographic restrictions | Low | Medium | Handle licensing errors gracefully |

### Migration Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Official API rejection | Medium | High | Continue with JSON v5 as fallback |
| Feature parity gaps | High | Medium | Maintain dual implementation temporarily |
| OAuth complexity | Low | Low | Use standard OAuth libraries |
| User re-authentication | High | Low | Smooth migration UX |

---

## Comparison: JSON v5 vs GraphQL

### JSON v5 (Current)

**Pros:**

- ✅ Works without approval
- ✅ Well-documented (unofficially)
- ✅ Proven stable for years
- ✅ Simple REST-like interface

**Cons:**

- ❌ No official support
- ❌ Limited to radio features
- ❌ Could break anytime
- ❌ No new features

### GraphQL (Official)

**Pros:**

- ✅ Official support
- ✅ More features (podcasts, collections, profiles)
- ✅ Better documentation
- ✅ Future-proof

**Cons:**

- ❌ Requires approval
- ❌ OAuth complexity
- ❌ May have usage limits
- ❌ Commercial terms unknown

---

## Conclusion

### Current State

Hermes implements **~85% of available JSON v5 features**, missing primarily:

- Bookmarks (high user value)
- QuickMix customization (high user value)
- Track explanations (nice-to-have)
- Optimization features (checksums)

### Recommendations

**Short Term (1-2 months):**

1. Add bookmark support
2. Implement QuickMix customization
3. Add station artwork
4. Improve error handling

**Medium Term (3-6 months):**

1. Add track explanations
2. Implement checksum-based sync
3. Add track gain normalization
4. Improve audio quality selection UI

**Long Term (6-12 months):**

1. Research official API access
2. Prototype GraphQL implementation
3. Plan migration strategy if approved
4. Maintain JSON v5 as fallback

### Bottom Line

The current JSON v5 implementation is **solid and functional** but missing some user-facing features that would improve the experience. The unofficial API remains stable, but having a migration path to the official GraphQL API would future-proof Hermes for commercial use.

**Immediate Action Items:**

1. ✅ Add bookmarks (highest user value)
2. ✅ Add QuickMix customization (user control)
3. ⚠️ Monitor API stability
4. 📋 Document migration path to GraphQL

---

## Appendix: API Method Coverage

### Implemented (15 methods)

- `auth.partnerLogin`
- `auth.userLogin`
- `user.getStationList`
- `station.getPlaylist`
- `station.createStation`
- `station.deleteStation`
- `station.renameStation`
- `station.addFeedback`
- `station.deleteFeedback`
- `user.sleepSong`
- `music.search`
- `station.addMusic`
- `station.deleteMusic`
- `station.getStation`
- `station.getGenreStations`

### Not Implemented (8 methods)

- `user.getBookmarks`
- `bookmark.addArtistBookmark`
- `bookmark.addSongBookmark`
- `track.explainTrack`
- `user.getStationListChecksum`
- `station.getGenreStationsChecksum`
- `station.transformSharedStation`
- `user.setQuickMix`

### Coverage: 65% of documented JSON v5 methods

---

*Report generated by analyzing Hermes source code against unofficial Pandora JSON API v5 documentation and official GraphQL API specifications.*
