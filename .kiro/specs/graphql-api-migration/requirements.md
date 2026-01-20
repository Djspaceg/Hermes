# Requirements Document

## Introduction

This document specifies the requirements for migrating Hermes from the legacy Pandora JSON API v5 to the official Pandora GraphQL Partner API. The migration will modernize the authentication system from Blowfish-encrypted partner/user login to OAuth 2.0, replace the custom JSON-RPC client with a GraphQL client, and update data models to support the new API's station/station factory paradigm.

The current implementation uses an undocumented JSON API v5 (documented at 6xq.net/pandora-apidoc) with Blowfish encryption and sync time mechanisms. The new GraphQL API at `ce.pandora.com/api/v1/graphql/graphql` uses OAuth 2.0 Bearer authentication and provides a more structured, officially supported interface.

## Glossary

- **GraphQL_Client**: The Swift service responsible for executing GraphQL queries and mutations against the Pandora API
- **OAuth_Manager**: The Swift service responsible for OAuth 2.0 authentication flow, token storage, and token refresh
- **Station**: A user-specific personalized radio station (ST prefix in GraphQL API)
- **Station_Factory**: A template for creating stations, not user-specific (SF prefix in GraphQL API)
- **Access_Token**: Short-lived OAuth 2.0 token used for API authentication (expires in ~4 hours)
- **Refresh_Token**: Long-lived OAuth 2.0 token used to obtain new access tokens (does not expire)
- **Device_UUID**: Unique identifier for the device, used to track playback state across sessions
- **Track_Token**: Unique identifier for a specific track in a playback session
- **Track_Interactions**: Available actions on a track (SKIP, REPLAY, THUMB, etc.) based on subscription tier
- **Playback_Source**: The entity being played (station, album, playlist, etc.)
- **Feedback**: User rating on a track (thumbs up/down)

## Requirements

### Requirement 1: OAuth 2.0 Authentication

**User Story:** As a user, I want to authenticate with Pandora using OAuth 2.0, so that I can securely access my account without storing my password locally.

#### Acceptance Criteria

1. WHEN the user initiates login, THE OAuth_Manager SHALL open a web browser to the Pandora OAuth authorization URL with appropriate client_id, redirect_uri, scope, state, and PKCE code_challenge parameters
2. WHEN the OAuth authorization server redirects back with an authorization code, THE OAuth_Manager SHALL exchange the code for access and refresh tokens via POST to the token endpoint
3. WHEN tokens are received, THE OAuth_Manager SHALL securely store the access_token and refresh_token in the macOS Keychain
4. WHEN an API request fails with an authentication error, THE OAuth_Manager SHALL automatically attempt to refresh the access_token using the refresh_token
5. WHEN the refresh_token grant succeeds, THE OAuth_Manager SHALL update the stored tokens and retry the failed request
6. IF the refresh_token grant fails, THEN THE OAuth_Manager SHALL clear stored tokens and prompt the user to re-authenticate
7. THE OAuth_Manager SHALL generate and verify PKCE code_challenge and code_verifier for enhanced security
8. THE OAuth_Manager SHALL generate and validate the state parameter to prevent CSRF attacks

### Requirement 2: GraphQL Client Infrastructure

**User Story:** As a developer, I want a robust GraphQL client layer, so that I can make type-safe API calls to the Pandora GraphQL endpoint.

#### Acceptance Criteria

1. THE GraphQL_Client SHALL send requests to `https://ce.pandora.com/api/v1/graphql/graphql` with Bearer token authentication
2. WHEN executing a query or mutation, THE GraphQL_Client SHALL include the OAuth access_token in the Authorization header as "Bearer {token}"
3. THE GraphQL_Client SHALL serialize GraphQL operations to JSON with operationName, variables, and query fields
4. WHEN a response is received, THE GraphQL_Client SHALL parse the JSON response and decode it into typed Swift models
5. IF the response contains an errors array, THEN THE GraphQL_Client SHALL extract error codes and messages and throw appropriate Swift errors
6. THE GraphQL_Client SHALL support both query and mutation operations
7. THE GraphQL_Client SHALL use Swift async/await for all network operations

### Requirement 3: Device UUID Management

**User Story:** As a user, I want my playback state to persist across app sessions, so that I can resume where I left off.

#### Acceptance Criteria

1. WHEN the app launches for the first time, THE OAuth_Manager SHALL generate a unique Device_UUID and store it persistently
2. THE GraphQL_Client SHALL include the Device_UUID in all playback-related queries and mutations
3. WHEN querying current playback state, THE GraphQL_Client SHALL use the stored Device_UUID to retrieve the last active source

### Requirement 4: Station Collection Retrieval

**User Story:** As a user, I want to see my collection of stations, so that I can select one to play.

#### Acceptance Criteria

1. WHEN the user is authenticated, THE GraphQL_Client SHALL query the collection.items endpoint with type filter for stations (ST)
2. WHEN station data is received, THE GraphQL_Client SHALL parse station id, name, and art URL into StationModel objects
3. THE GraphQL_Client SHALL support pagination for large station collections using cursor-based pagination
4. THE GraphQL_Client SHALL support sorting stations by name or collection time
5. WHEN a station is added to the collection, THE StationsViewModel SHALL update the local stations list

### Requirement 5: Station Playback

**User Story:** As a user, I want to play a station and hear music, so that I can enjoy personalized radio.

#### Acceptance Criteria

1. WHEN the user selects a station to play, THE GraphQL_Client SHALL execute the playback.setSource mutation with the station ID and Device_UUID
2. WHEN setSource succeeds, THE GraphQL_Client SHALL receive and parse the current track metadata including audioUrl, trackToken, interactions, and track details
3. THE AudioStreamer SHALL play the audio from the returned audioUrl
4. WHEN a track ends, THE GraphQL_Client SHALL execute the playback.setEnded mutation to advance to the next track
5. WHILE a track is playing, THE GraphQL_Client SHALL periodically execute the playback.setProgress mutation to report elapsed time
6. WHEN the user skips a track, THE GraphQL_Client SHALL execute the playback.skip mutation and receive the next track
7. IF the skip mutation returns an error due to skip limits, THEN THE PlayerViewModel SHALL display an appropriate message to the user

### Requirement 6: Audio URL Management

**User Story:** As a user, I want uninterrupted playback, so that I can enjoy music without audio dropouts.

#### Acceptance Criteria

1. WHEN an audioUrl is received, THE AudioStreamer SHALL begin playback immediately
2. THE GraphQL_Client SHALL track audio URL expiration (5 minutes for on-demand, 1 hour for stations)
3. WHEN an audio URL is about to expire during playback, THE GraphQL_Client SHALL request a fresh URL before expiration
4. IF an audio URL expires during playback, THEN THE GraphQL_Client SHALL request a new URL and resume playback

### Requirement 7: Track Feedback

**User Story:** As a user, I want to rate songs with thumbs up or thumbs down, so that Pandora can personalize my stations.

#### Acceptance Criteria

1. WHEN the user gives a thumbs up, THE GraphQL_Client SHALL execute the feedback.setFeedback mutation with value UP, targetId, sourceContextId, trackToken, deviceUuid, and elapsedTime
2. WHEN the user gives a thumbs down, THE GraphQL_Client SHALL execute the feedback.setFeedback mutation with value DOWN and the track SHALL be skipped
3. WHEN feedback is set successfully, THE PlayerViewModel SHALL update the UI to reflect the rating
4. IF the track interactions do not include THUMB, THEN THE PlayerView SHALL disable the feedback buttons
5. WHEN the user removes a rating, THE GraphQL_Client SHALL execute the feedback.removeFeedback mutation

### Requirement 8: Search Functionality

**User Story:** As a user, I want to search for artists and songs, so that I can create new stations.

#### Acceptance Criteria

1. WHEN the user enters a search query, THE GraphQL_Client SHALL execute the search query with types [SF, ST, AR, TR] and the query string
2. WHEN search results are received, THE GraphQL_Client SHALL parse results into SearchResult models with id, name, type, and art URL
3. THE SearchView SHALL display results grouped by type (Station Factories, Artists, Tracks)
4. THE GraphQL_Client SHALL support pagination for search results

### Requirement 9: Station Creation

**User Story:** As a user, I want to create new stations from search results, so that I can discover new music.

#### Acceptance Criteria

1. WHEN the user selects a Station Factory (SF) from search results, THE GraphQL_Client SHALL execute playback.setSource with the SF id
2. WHEN setSource succeeds with an SF, THE GraphQL_Client SHALL receive the user-specific Station (ST) id that was created
3. THE StationsViewModel SHALL add the new station to the local collection
4. THE PlayerViewModel SHALL begin playback of the new station

### Requirement 10: Track Interactions Enforcement

**User Story:** As a user, I want to understand what actions I can take on a track, so that I don't encounter unexpected errors.

#### Acceptance Criteria

1. WHEN track metadata is received, THE PlayerViewModel SHALL parse the interactions array to determine available actions
2. IF SKIP is not in interactions, THEN THE PlayerView SHALL disable the skip button
3. IF REPLAY is not in interactions, THEN THE PlayerView SHALL disable the replay button
4. IF THUMB is not in interactions, THEN THE PlayerView SHALL disable the feedback buttons
5. THE PlayerView SHALL display appropriate messaging when an action is unavailable due to subscription tier

### Requirement 11: Error Handling

**User Story:** As a user, I want clear error messages when something goes wrong, so that I can understand and resolve issues.

#### Acceptance Criteria

1. WHEN a GraphQL response contains errors, THE GraphQL_Client SHALL map error codes to user-friendly messages
2. IF a network error occurs, THEN THE GraphQL_Client SHALL throw a NetworkError with the underlying cause
3. IF an authentication error occurs, THEN THE OAuth_Manager SHALL attempt token refresh before surfacing the error
4. WHEN an error is surfaced to the UI, THE ErrorView SHALL display a clear message and recovery action if available
5. THE GraphQL_Client SHALL log all errors with sufficient context for debugging

### Requirement 12: Migration from Legacy API

**User Story:** As a user, I want a seamless transition to the new API, so that I don't lose my listening experience.

#### Acceptance Criteria

1. WHEN the app is updated, THE OAuth_Manager SHALL detect existing legacy credentials and prompt for OAuth re-authentication
2. THE app SHALL remove legacy Blowfish encryption code after migration is complete
3. THE app SHALL remove legacy PandoraDevice configuration after migration is complete
4. THE app SHALL remove legacy sync time mechanism after migration is complete
5. WHEN OAuth authentication succeeds, THE app SHALL fetch and display the user's existing stations from the GraphQL API

### Requirement 13: Token Serialization

**User Story:** As a developer, I want OAuth tokens to be securely persisted, so that users don't need to re-authenticate on every app launch.

#### Acceptance Criteria

1. THE OAuth_Manager SHALL serialize access_token, refresh_token, and expiration time to the Keychain
2. WHEN the app launches, THE OAuth_Manager SHALL deserialize stored tokens and validate the access_token expiration
3. IF the access_token is expired but refresh_token exists, THEN THE OAuth_Manager SHALL automatically refresh tokens
4. THE OAuth_Manager SHALL use Keychain access control to protect tokens from unauthorized access

### Requirement 14: Playback Progress Reporting

**User Story:** As a user, I want my playback progress to be tracked, so that I can resume tracks and get accurate listening history.

#### Acceptance Criteria

1. WHILE a track is playing, THE PlayerViewModel SHALL report progress at the frequency specified by the API response
2. WHEN reporting progress, THE GraphQL_Client SHALL execute playback.setProgress with deviceUuid, elapsedTime, and trackToken
3. WHEN the app is backgrounded or closed, THE PlayerViewModel SHALL report final progress before stopping

### Requirement 15: Subscription Tier Awareness

**User Story:** As a user, I want the app to respect my subscription tier, so that I only see features available to me.

#### Acceptance Criteria

1. WHEN the user authenticates, THE GraphQL_Client SHALL query the listener's subscription tier and allowed types
2. THE app SHALL store the subscription tier and use it to conditionally enable features
3. IF the user has a free subscription, THEN THE app SHALL only allow station and podcast playback
4. IF the user has a Premium subscription, THEN THE app SHALL enable on-demand playback of albums, tracks, and playlists
