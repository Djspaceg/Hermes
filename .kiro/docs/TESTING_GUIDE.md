# Hermes Testing Guide

**Date:** January 14, 2026  
**Purpose:** Verify Swift view models have complete parity with Objective-C controllers

---

## Overview

This testing framework ensures that the Swift migration maintains 100% functional parity with the original Objective-C code. Tests are based on the **behavior** of the legacy controllers, not their implementation.

## Why Unit Tests?

### Benefits

1. **Repeatable Verification** - Run tests anytime, not just manual checks
2. **Regression Prevention** - Catch bugs before they reach users
3. **Documentation** - Tests show how code should behave
4. **Confidence** - Delete legacy code knowing nothing is lost
5. **Refactoring Safety** - Change implementation without breaking behavior

### Migration-Specific Benefits

- **Parity Verification** - Prove Swift matches Objective-C behavior
- **Safe Deletion** - Delete Objective-C controllers with confidence
- **Future-Proofing** - Prevent regressions as code evolves

---

## Test Structure

### Current Test Files

```
Tests/
├── ViewModels/
│   ├── LoginViewModelTests.swift          (✅ 15 tests)
│   ├── StationsViewModelTests.swift       (✅ 20 tests)
│   └── HistoryViewModelTests.swift        (✅ 15 tests)
└── README.md
```

### Mapping to Objective-C

| Swift View Model | Objective-C Controller | Test File | Status |
|-----------------|------------------------|-----------|--------|
| LoginViewModel | AuthController | LoginViewModelTests | ✅ Complete |
| StationsViewModel | StationsController | StationsViewModelTests | ✅ Complete |
| HistoryViewModel | HistoryController | HistoryViewModelTests | ✅ Complete |
| StationEditViewModel | StationController | StationEditViewModelTests | ⏳ TODO |
| PlayerViewModel | PlaybackController | PlayerViewModelTests | ⏳ TODO |

---

## Running Tests

### Option 1: Xcode (Recommended)

1. Open `Hermes.xcodeproj`
2. **Add Test Target** (first time only):
   - File → New → Target
   - Select "Unit Testing Bundle"
   - Name: `HermesTests`
   - Add test files from `Tests/` directory

3. **Run All Tests**:
   - Press `Cmd+U`
   - Or Product → Test

4. **Run Individual Test**:
   - Click diamond icon next to test method
   - Or place cursor in test and press `Cmd+U`

5. **View Results**:
   - Test Navigator (Cmd+6)
   - Green checkmarks = passing
   - Red X = failing

### Option 2: Command Line

```bash
# Run all tests
make test

# Run with pretty output (requires xcpretty)
make test-verbose

# Run specific test class
xcodebuild test -project Hermes.xcodeproj -scheme HermesTests \
  -only-testing:HermesTests/LoginViewModelTests

# Run specific test method
xcodebuild test -project Hermes.xcodeproj -scheme HermesTests \
  -only-testing:HermesTests/LoginViewModelTests/testEmailValidation_ValidEmail
```

### Option 3: Continuous Integration

Tests run automatically on:

- Every commit (GitHub Actions)
- Pull requests
- Release builds

---

## Test Examples

### Example 1: Email Validation (from AuthController)

**Original Objective-C:**

```objc
// AuthController.m
#define ROUGH_EMAIL_REGEX @"[^\\s@]+@[^\\s@]+\\.[^\\s@]+"

- (void)controlTextDidChange:(NSNotification *)obj {
  NSPredicate *emailTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", ROUGH_EMAIL_REGEX];
  
  [login setEnabled:
   [spinner isHidden] &&
   [emailTest evaluateWithObject:[username stringValue]] &&
   ![[password stringValue] isEqualToString:@""]];
}
```

**Swift Test:**

```swift
func testEmailValidation_ValidEmail() {
    // Given
    sut.username = "user@example.com"
    
    // Then
    XCTAssertTrue(sut.isValidEmail, "Valid email should pass validation")
}

func testCanSubmit_ValidCredentials() {
    // Given
    sut.username = "user@example.com"
    sut.password = "password123"
    
    // Then
    XCTAssertTrue(sut.canSubmit, "Valid credentials should enable submit")
}
```

### Example 2: History Limit (from HistoryController)

**Original Objective-C:**

```objc
// HistoryController.m
#define HISTORY_LIMIT 20

- (void) addSong:(Song *)song {
  [self insertObject:song inSongsAtIndex:0];
  
  while ([songs count] > HISTORY_LIMIT) {
    [self removeObjectFromSongsAtIndex:HISTORY_LIMIT];
  }
}
```

**Swift Test:**

```swift
func testHistoryLimit_EnforcesMaximum() {
    // Given - Create 25 songs (limit is 20)
    let songs = (1...25).map { createMockSong(title: "Song \($0)") }
    
    // When
    for song in songs {
        sut.addToHistory(song)
    }
    
    // Then
    XCTAssertEqual(sut.historyItems.count, 20, "Should enforce 20 item limit")
    XCTAssertEqual(sut.historyItems.first?.title, "Song 25", "Most recent song should be first")
}
```

### Example 3: Station Sorting (from StationsController)

**Original Objective-C:**

```objc
// StationsController.m
- (void) sortStations {
  Pandora *p = [self pandora];
  Station *selected = [self selectedStation];
  [p sortStations:PREF_KEY_INT(SORT_STATIONS)];
  if (selected != nil) {
    [self selectStation:selected];
  }
  [stationsTable reloadData];
}
```

**Swift Test:**

```swift
func testSorting_ByName() {
    // Given
    let stationC = createMockStation(name: "Charlie Station", id: "c")
    let stationA = createMockStation(name: "Alpha Station", id: "a")
    let stationB = createMockStation(name: "Bravo Station", id: "b")
    sut.stations = [stationC, stationA, stationB].map { StationModel(station: $0) }
    
    // When
    let sorted = sut.sortedStations(by: .name)
    
    // Then
    XCTAssertEqual(sorted[0].name, "Alpha Station")
    XCTAssertEqual(sorted[1].name, "Bravo Station")
    XCTAssertEqual(sorted[2].name, "Charlie Station")
}
```

---

## Test Patterns

### Pattern 1: Given-When-Then

```swift
func testFeature_Scenario() {
    // Given - Setup initial state
    sut.username = "user@example.com"
    
    // When - Perform action
    sut.validate()
    
    // Then - Assert expected outcome
    XCTAssertTrue(sut.isValid)
}
```

### Pattern 2: Async Testing

```swift
func testAuthenticate_Success() async throws {
    // Given
    sut.username = "user@example.com"
    sut.password = "password123"
    mockPandora.shouldSucceed = true
    
    // When
    try await sut.authenticate()
    
    // Then
    XCTAssertFalse(sut.isLoading)
    XCTAssertNil(sut.errorMessage)
}
```

### Pattern 3: Notification Testing

```swift
func testAddSong_PostsDistributedNotification() {
    // Given
    let expectation = XCTestExpectation(description: "Notification posted")
    let song = createMockSong(title: "Test Song")
    
    let observer = DistributedNotificationCenter.default().addObserver(
        forName: NSNotification.Name("hermes.song"),
        object: "hermes",
        queue: .main
    ) { notification in
        XCTAssertNotNil(notification.userInfo)
        expectation.fulfill()
    }
    
    // When
    sut.addToHistory(song)
    
    // Then
    wait(for: [expectation], timeout: 1.0)
    DistributedNotificationCenter.default().removeObserver(observer)
}
```

### Pattern 4: Mock Objects

```swift
@MainActor
class MockPandora: Pandora {
    var shouldSucceed = true
    var authenticateCalled = false
    var lastUsername: String?
    
    override func authenticate(_ username: String, password: String, request: Any?) -> Bool {
        authenticateCalled = true
        lastUsername = username
        return shouldSucceed
    }
}
```

---

## Adding New Tests

### Step 1: Identify Objective-C Behavior

Read the Objective-C controller and identify:

- Public methods (IBActions, public API)
- State changes
- Side effects (notifications, persistence)
- Edge cases

### Step 2: Create Test File

```swift
//
//  MyViewModelTests.swift
//  HermesTests
//
//  Tests for MyViewModel to verify parity with MyController
//

import XCTest
@testable import Hermes

@MainActor
final class MyViewModelTests: XCTestCase {
    
    var sut: MyViewModel!
    
    override func setUp() async throws {
        try await super.setUp()
        sut = MyViewModel()
    }
    
    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }
    
    // MARK: - Tests
}
```

### Step 3: Write Tests

For each Objective-C method, write tests covering:

- Happy path (normal operation)
- Edge cases (empty, nil, invalid input)
- Error conditions
- State changes
- Side effects

### Step 4: Run and Verify

```bash
make test
```

All tests should pass before marking migration complete.

---

## Test Coverage Goals

### Minimum Coverage

- **View Models**: 80%+ line coverage
- **Utilities**: 70%+ line coverage
- **Critical Paths**: 100% coverage
  - Authentication
  - Playback control
  - Data persistence

### Measuring Coverage

1. Edit Scheme → Test → Options
2. Enable "Code Coverage"
3. Select "Hermes" target
4. Run tests
5. View Report Navigator (Cmd+9) → Coverage

---

## Troubleshooting

### Tests Won't Run

**Problem:** "No scheme named HermesTests"

**Solution:** Create test target in Xcode:

1. File → New → Target
2. Unit Testing Bundle
3. Name: `HermesTests`
4. Add test files

### Tests Fail

**Problem:** "Cannot find 'Hermes' in scope"

**Solution:** Add `@testable import Hermes` to test file

**Problem:** "Main actor-isolated property accessed from nonisolated context"

**Solution:** Mark test class with `@MainActor`

### Mock Objects Don't Work

**Problem:** Mock methods not called

**Solution:** Ensure mock overrides correct method signature:

```swift
override func authenticate(_ username: String, password: String, request: Any?) -> Bool {
    // Must match exact signature
}
```

---

## Best Practices

### ✅ Do

- **Test behavior, not implementation**
  - Test what the code does, not how it does it
  
- **One assertion per test** (when possible)
  - Makes failures easier to diagnose
  
- **Use descriptive names**
  - `testEmailValidation_ValidEmail` not `test1`
  
- **Clean up in tearDown**
  - Prevent test pollution
  
- **Mock external dependencies**
  - No network calls, no file I/O (except temp files)
  
- **Test edge cases**
  - Empty strings, nil values, boundary conditions

### ❌ Don't

- **Don't test private methods**
  - Test public API only
  
- **Don't make network calls**
  - Use mocks
  
- **Don't write flaky tests**
  - Tests should be deterministic
  
- **Don't ignore failures**
  - Fix or document why test is disabled
  
- **Don't skip tearDown**
  - Always clean up

---

## Migration Workflow

### Phase 1: Write Tests (Current)

1. ✅ Create test files for each view model
2. ✅ Map Objective-C methods to test cases
3. ✅ Write tests based on Objective-C behavior
4. ✅ Run tests against Swift view models
5. ✅ Fix any failures

### Phase 2: Verify Parity

1. ⏳ All tests pass
2. ⏳ Code coverage meets goals
3. ⏳ Manual testing confirms behavior
4. ⏳ No regressions found

### Phase 3: Delete Legacy Code

1. ⏳ Tests still pass with Objective-C controllers removed
2. ⏳ App functions correctly
3. ⏳ No references to deleted code

---

## Success Criteria

Migration is complete when:

✅ **All tests pass**

- 50+ tests across all view models
- 80%+ code coverage
- No flaky tests

✅ **Parity verified**

- Every Objective-C method has corresponding test
- All edge cases covered
- All side effects tested

✅ **Legacy code deleted**

- Tests still pass
- App still works
- No dead code remains

---

## Next Steps

### Immediate

1. **Add test target to Xcode project**
   - File → New → Target → Unit Testing Bundle
   - Name: `HermesTests`
   - Add test files from `Tests/` directory

2. **Run existing tests**

   ```bash
   make test
   ```

3. **Fix any failures**
   - Review test output
   - Update Swift code or tests as needed

### Short Term

1. **Complete remaining tests**
   - StationEditViewModel
   - PlayerViewModel
   - KeychainManager
   - SettingsManager

2. **Achieve coverage goals**
   - 80%+ for view models
   - 70%+ for utilities

3. **Document any gaps**
   - Features not tested
   - Known limitations

### Long Term

1. **Continuous testing**
   - Run tests on every commit
   - Block PRs with failing tests
   - Monitor coverage trends

2. **Expand test suite**
   - Integration tests
   - UI tests
   - Performance tests

---

## Resources

- **XCTest Documentation**: <https://developer.apple.com/documentation/xctest>
- **Testing in Xcode**: <https://developer.apple.com/documentation/xcode/testing-your-apps-in-xcode>
- **Swift Testing Best Practices**: <https://www.swiftbysundell.com/articles/unit-testing-in-swift/>

---

**Last Updated:** January 14, 2026  
**Test Count:** 50+ tests  
**Coverage:** TBD (after test target added)
