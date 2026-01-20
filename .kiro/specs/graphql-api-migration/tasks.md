# Implementation Plan: Pandora GraphQL API Migration

## Overview

This implementation plan migrates Hermes from the legacy Pandora JSON API v5 to the official GraphQL Partner API. The migration is structured in phases to allow incremental progress while maintaining app functionality. Each phase builds on the previous, with checkpoints to verify correctness before proceeding.

## Tasks

- [ ] 1. Set up OAuth 2.0 infrastructure
  - [ ] 1.1 Create OAuthManager with PKCE support
    - Create `Sources/Swift/Services/OAuthManager.swift`
    - Implement PKCE code_verifier and code_challenge generation using SHA256
    - Implement state token generation for CSRF protection
    - Implement authorization URL construction with all required parameters
    - _Requirements: 1.1, 1.7, 1.8_
  
  - [ ] 1.2 Write property tests for PKCE and OAuth URL construction
    - **Property 1: OAuth URL Construction**
    - **Property 2: PKCE Round-Trip**
    - **Property 3: State Parameter Validation**
    - **Validates: Requirements 1.1, 1.7, 1.8**
  
  - [ ] 1.3 Implement OAuth callback handling
    - Handle redirect URL with authorization code
    - Validate state parameter matches original
    - Exchange authorization code for tokens via POST to token endpoint
    - Include Basic auth header with client_id:client_secret
    - _Requirements: 1.2, 1.8_
  
  - [ ] 1.4 Implement token storage in Keychain
    - Extend KeychainManager to store OAuth tokens
    - Store access_token, refresh_token, and expiration date
    - Implement secure retrieval and deletion
    - _Requirements: 1.3, 13.1, 13.2_
  
  - [ ] 1.5 Write property test for token storage round-trip
    - **Property 4: Token Storage Round-Trip**
    - **Validates: Requirements 1.3, 13.1, 13.2**
  
  - [ ] 1.6 Implement automatic token refresh
    - Check token expiration before API calls
    - Implement refresh_token grant flow
    - Update stored tokens on successful refresh
    - Clear tokens and trigger re-auth on refresh failure
    - _Requirements: 1.4, 1.5, 1.6, 13.3_

- [ ] 2. Checkpoint - Verify OAuth infrastructure
  - Ensure all OAuth tests pass
  - Manually test OAuth flow with Pandora (requires partner credentials)
  - Ask the user if questions arise

- [ ] 3. Create GraphQL client infrastructure
  - [ ] 3.1 Create GraphQL operation types
    - Create `Sources/Swift/Services/GraphQL/GraphQLTypes.swift`
    - Implement GraphQLOperation struct with operationName, query, variables
    - Implement GraphQLResponse<T> wrapper with data and errors
    - Implement GraphQLError with message, locations, path, extensions
    - _Requirements: 2.3, 2.5_
  
  - [ ] 3.2 Write property tests for GraphQL serialization
    - **Property 6: GraphQL Operation Serialization**
    - **Property 7: GraphQL Response Parsing Round-Trip**
    - **Property 8: GraphQL Error Extraction**
    - **Validates: Requirements 2.3, 2.4, 2.5**
  
  - [ ] 3.3 Create PandoraGraphQLClient actor
    - Create `Sources/Swift/Services/PandoraGraphQLClient.swift`
    - Implement as Swift actor for thread safety
    - Inject OAuthManager for token retrieval
    - Implement generic query<T> and mutate<T> methods
    - Add Bearer token to Authorization header
    - _Requirements: 2.1, 2.2, 2.6, 2.7_
  
  - [ ] 3.4 Write property test for Bearer token header
    - **Property 5: Bearer Token Header**
    - **Validates: Requirements 2.1, 2.2**
  
  - [ ] 3.5 Implement error handling and retry logic
    - Map GraphQL error codes to PandoraAPIError
    - Implement automatic token refresh on 401/UNAUTHENTICATED
    - Implement retry with exponential backoff for network errors
    - _Requirements: 11.1, 11.2, 11.3_
  
  - [ ] 3.6 Write property test for error code mapping
    - **Property 21: Error Code to Message Mapping**
    - **Validates: Requirements 11.1**

- [ ] 4. Implement Device UUID management
  - [ ] 4.1 Add Device UUID generation and storage
    - Generate UUID on first launch using UUID().uuidString
    - Store in UserDefaults for persistence
    - Expose via OAuthManager or dedicated DeviceManager
    - _Requirements: 3.1_
  
  - [ ] 4.2 Write property test for Device UUID
    - **Property 9: Device UUID Uniqueness**
    - **Property 10: Device UUID Inclusion in Playback**
    - **Validates: Requirements 3.1, 3.2**

- [ ] 5. Checkpoint - Verify GraphQL client
  - Ensure all GraphQL client tests pass
  - Test basic query execution against Pandora API
  - Ask the user if questions arise

- [ ] 6. Create GraphQL data models
  - [ ] 6.1 Create station models
    - Create `Sources/Swift/Models/GraphQL/GraphQLStation.swift`
    - Implement GraphQLStation with id, name, art
    - Implement GraphQLStationFactory for SF types
    - Implement StationCollectionResponse with pagination
    - _Requirements: 4.2_
  
  - [ ] 6.2 Write property test for station parsing
    - **Property 11: Station Parsing**
    - **Validates: Requirements 4.2**
  
  - [ ] 6.3 Create playback models
    - Create `Sources/Swift/Models/GraphQL/PlaybackModels.swift`
    - Implement TrackItem with audioUrl, trackToken, interactions
    - Implement TrackMetadata with name, duration, art, artist, album
    - Implement TrackInteraction enum (SKIP, REPLAY, THUMB)
    - Implement PlaybackSourceResponse and related types
    - _Requirements: 5.2, 10.1_
  
  - [ ] 6.4 Write property tests for playback model parsing
    - **Property 13: Track Metadata Parsing**
    - **Property 20: Interactions Array Parsing**
    - **Validates: Requirements 5.2, 10.1**
  
  - [ ] 6.5 Create search models
    - Create `Sources/Swift/Models/GraphQL/SearchModels.swift`
    - Implement SearchItem as enum with associated values
    - Implement ArtistSearchResult, TrackSearchResult, AlbumSearchResult
    - Implement SearchResponse with pagination
    - _Requirements: 8.2_
  
  - [ ] 6.6 Write property test for search result parsing
    - **Property 18: Search Result Parsing**
    - **Validates: Requirements 8.2**
  
  - [ ] 6.7 Create feedback models
    - Create `Sources/Swift/Models/GraphQL/FeedbackModels.swift`
    - Implement FeedbackValue enum (UP, DOWN)
    - Implement FeedbackResponse
    - _Requirements: 7.1_

- [ ] 7. Implement station collection operations
  - [ ] 7.1 Add fetchStations to GraphQL client
    - Implement collection.items query with ST type filter
    - Support sorting by name or collection time
    - Support cursor-based pagination
    - _Requirements: 4.1, 4.3, 4.4_
  
  - [ ] 7.2 Write property test for setSource mutation construction
    - **Property 12: SetSource Mutation Construction**
    - **Validates: Requirements 5.1**
  
  - [ ] 7.3 Update StationsViewModel to use GraphQL client
    - Replace Pandora.fetchStations() calls with GraphQL client
    - Convert GraphQLStation to StationModel for UI
    - Handle pagination for large collections
    - _Requirements: 4.1, 4.5_

- [ ] 8. Checkpoint - Verify station fetching
  - Ensure stations load correctly from GraphQL API
  - Verify station list displays in UI
  - Ask the user if questions arise

- [ ] 9. Implement playback operations
  - [ ] 9.1 Add playback mutations to GraphQL client
    - Implement setSource mutation with sourceId and deviceUuid
    - Implement skip mutation
    - Implement setProgress mutation
    - Implement setEnded mutation
    - _Requirements: 5.1, 5.4, 5.5, 5.6_
  
  - [ ] 9.2 Write property test for progress mutation construction
    - **Property 22: Progress Mutation Construction**
    - **Validates: Requirements 14.2**
  
  - [ ] 9.3 Create PlaybackManager
    - Create `Sources/Swift/Services/PlaybackManager.swift`
    - Coordinate between GraphQL client and AudioStreamer
    - Manage current track state and available interactions
    - Implement periodic progress reporting
    - _Requirements: 5.1, 5.2, 5.5, 14.1, 14.2_
  
  - [ ] 9.4 Implement audio URL expiration handling
    - Track audio URL expiration times
    - Request fresh URL before expiration during playback
    - Handle expired URL recovery
    - _Requirements: 6.2, 6.3, 6.4_
  
  - [ ] 9.5 Write property test for audio URL expiration
    - **Property 14: Audio URL Expiration Tracking**
    - **Validates: Requirements 6.2**
  
  - [ ] 9.6 Update PlayerViewModel to use PlaybackManager
    - Replace PlaybackController calls with PlaybackManager
    - Update UI bindings for new track model
    - Handle interaction-based button states
    - _Requirements: 5.7, 10.2, 10.3, 10.4, 10.5_
  
  - [ ] 9.7 Write property test for interaction-based UI state
    - **Property 16: Interaction-Based UI State**
    - **Validates: Requirements 7.4, 10.2, 10.3**

- [ ] 10. Checkpoint - Verify playback
  - Ensure station playback works end-to-end
  - Verify skip, progress reporting, and track advancement
  - Verify interaction-based button states
  - Ask the user if questions arise

- [ ] 11. Implement feedback operations
  - [ ] 11.1 Add feedback mutations to GraphQL client
    - Implement setFeedback mutation with all required parameters
    - Implement removeFeedback mutation
    - _Requirements: 7.1, 7.2, 7.5_
  
  - [ ] 11.2 Write property test for feedback mutation construction
    - **Property 15: Feedback Mutation Construction**
    - **Validates: Requirements 7.1**
  
  - [ ] 11.3 Update PlayerViewModel for feedback
    - Implement thumbsUp() using GraphQL setFeedback
    - Implement thumbsDown() using GraphQL setFeedback (also skips)
    - Implement removeFeedback()
    - Update UI state on feedback success
    - _Requirements: 7.1, 7.2, 7.3, 7.5_

- [ ] 12. Implement search and station creation
  - [ ] 12.1 Add search query to GraphQL client
    - Implement search query with types and pagination
    - Support SF, ST, AR, TR search types
    - _Requirements: 8.1, 8.4_
  
  - [ ] 12.2 Write property test for search query construction
    - **Property 17: Search Query Construction**
    - **Validates: Requirements 8.1**
  
  - [ ] 12.3 Create SearchViewModel
    - Create `Sources/Swift/ViewModels/SearchViewModel.swift`
    - Implement search with debouncing
    - Group results by type for display
    - _Requirements: 8.1, 8.2, 8.3_
  
  - [ ] 12.4 Implement station creation from search
    - Handle SF selection to create new station
    - Parse returned ST id from setSource response
    - Add new station to collection
    - Begin playback of new station
    - _Requirements: 9.1, 9.2, 9.3, 9.4_
  
  - [ ] 12.5 Write property test for SF to ST conversion
    - **Property 19: Station Factory to Station Conversion**
    - **Validates: Requirements 9.2**

- [ ] 13. Checkpoint - Verify search and station creation
  - Ensure search returns results
  - Verify station creation from search results
  - Ask the user if questions arise

- [ ] 14. Implement subscription tier handling
  - [ ] 14.1 Query listener subscription tier
    - Add listener query to GraphQL client
    - Fetch allowed search and collection types
    - Store subscription tier in app state
    - _Requirements: 15.1_
  
  - [ ] 14.2 Write property test for subscription-based feature gating
    - **Property 23: Subscription-Based Feature Gating**
    - **Validates: Requirements 15.2, 15.3, 15.4**
  
  - [ ] 14.3 Implement feature gating based on subscription
    - Conditionally enable on-demand playback for Premium
    - Restrict free tier to stations and podcasts
    - Update UI to reflect available features
    - _Requirements: 15.2, 15.3, 15.4_

- [ ] 15. Create OAuth login UI
  - [ ] 15.1 Create OAuthLoginView
    - Create `Sources/Swift/Views/OAuthLoginView.swift`
    - Display "Sign in with Pandora" button
    - Show loading state during OAuth flow
    - Handle OAuth callback and display success/error
    - _Requirements: 1.1, 1.2_
  
  - [ ] 15.2 Update LoginViewModel for OAuth
    - Replace username/password auth with OAuth flow
    - Handle legacy credential detection and migration prompt
    - _Requirements: 12.1_
  
  - [ ] 15.3 Update app navigation for OAuth
    - Update ContentView to show OAuthLoginView when not authenticated
    - Handle OAuth callback URL in app delegate
    - _Requirements: 1.2, 12.5_

- [ ] 16. Checkpoint - Verify OAuth login UI
  - Ensure OAuth login flow works end-to-end
  - Verify token storage and automatic refresh
  - Ask the user if questions arise

- [ ] 17. Migration and cleanup
  - [ ] 17.1 Add legacy credential migration
    - Detect existing username/password in Keychain
    - Prompt user to re-authenticate with OAuth
    - Clear legacy credentials after successful OAuth
    - _Requirements: 12.1, 12.5_
  
  - [ ] 17.2 Update error handling UI
    - Update ErrorView to display GraphQL errors
    - Add recovery actions where applicable
    - _Requirements: 11.4_
  
  - [ ] 17.3 Remove legacy Pandora API code (after verification)
    - Remove Blowfish encryption (Crypt.h/m)
    - Remove PandoraDevice configuration
    - Remove sync time mechanism from Pandora.m
    - Update bridging header
    - _Requirements: 12.2, 12.3, 12.4_

- [ ] 18. Final checkpoint - Full integration verification
  - Run all property tests and unit tests
  - Verify complete user flow: OAuth login → stations → playback → feedback → search
  - Verify error handling and recovery
  - Ask the user if questions arise

## Notes

- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation before proceeding
- Property tests validate universal correctness properties from the design document
- The legacy Pandora API code should only be removed after full verification of GraphQL implementation
- Partner API credentials (client_id, client_secret) are required before OAuth implementation can be tested
