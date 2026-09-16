# Swift Testing migration status

The suite keeps the following files on XCTest until their asynchronous behavior can be translated without changing test semantics:

- `DependencyInjectionPropertyTests.swift`: repeated positive and inverted Combine notification waits.
- `HistoryViewModelTests.swift`: distributed-notification waiter with early completion and timeout behavior.
- `ImageCacheTests.swift`: callback waiters whose cancellation and late-callback behavior must remain intact.
- `MockPandoraTests.swift`: 22 test-shaped declarations but only 11 effective tests because 11 functions are currently outside the XCTestCase type.
- `NotificationBridgeTests.swift`: scheduler ordering, background posting, and inverted waits.
- `NotificationConsistencyTests.swift`: multi-observer ordering, synchronous delivery, and timeout behavior.
- `NotificationDebouncingTests.swift`: debounce scheduler timing and burst ordering.
- `PlaylistInvariantsTests.swift`: notification waiter semantics.
- `PlaylistManagementTests.swift`: positive notification waiters with asynchronous timeout windows.
- `StationArtworkLoaderTests.swift`: positive and inverted Combine notification waits.
- `UpdateCheckerTests.swift`: URLProtocol lifecycle combined with asynchronous notification waits.

These files retain 134 effective XCTest tests. The migrated files and the 90 tests that were already using Swift Testing account for the other 271 tests, preserving the whole-suite total of 405.
