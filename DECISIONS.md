# Compiler Warning Cleanup Decisions

1. Worktree and scope

   - Merge branch: `fix/compiler-warnings-20260917-session`, based on `0684f32`.
   - The abandoned duplicate branch `fix/compiler-warnings-20260917` had no unique changes and was deleted before this patch.
   - No files under `Sources/Swift/Services/Audio/`, `PlaybackController.swift`, `KeychainManager.swift`, `AppState.swift`, or the credential path are changed.
   - This is build and test-source work only. It has no user-visible surface, so no screenshot or recording is required.

2. Baseline warning inventory

   `make` exited 0 and emitted these two warning lines:

   ```text
   --- xcodebuild: WARNING: Using the first of multiple matching destinations:
   { platform:macOS, arch:arm64, id:00006040-0012513A0AF9801C, name:My Mac }
   { platform:macOS, arch:x86_64, id:00006040-0012513A0AF9801C, name:My Mac }
   { platform:macOS, name:Any Mac }

   2026-09-17 02:36:51.173 appintentsmetadataprocessor[54436:5062681] warning: Metadata extraction skipped, no AppIntents.framework dependency found
   ```

   `make test` exited 0 with 47 displayed warning diagnostics: one destination warning, 44 renderings of the 22 Swift test diagnostics (headline and source-caret line), and two App Intents processor warnings. The complete logical warning list, in log order, follows:

   ```text
   --- xcodebuild: WARNING: Using the first of multiple matching destinations:
   2026-09-17 02:38:53.437 appintentsmetadataprocessor[60488:5086195] warning: Metadata extraction skipped, no AppIntents.framework dependency found
   HermesTests/Tests/UpdateCheckerTests.swift:131:13: warning: capture of 'receivedUserInfo' with non-Sendable type '[AnyHashable : Any]?' in a '@Sendable' closure [#SendableClosureCaptures]
   HermesTests/Tests/UpdateCheckerTests.swift:172:13: warning: capture of 'receivedUserInfo' with non-Sendable type '[AnyHashable : Any]?' in a '@Sendable' closure [#SendableClosureCaptures]
   HermesTests/Tests/UpdateCheckerTests.swift:195:13: warning: capture of 'receivedUserInfo' with non-Sendable type '[AnyHashable : Any]?' in a '@Sendable' closure [#SendableClosureCaptures]
   HermesTests/Tests/StationsViewModelTests.swift:30:32: warning: comparing non-optional value of type '[Station]' to 'nil' always returns true
   HermesTests/Tests/AppStateFactoryTests.swift:32:43: warning: comparing non-optional value of type 'LoginViewModel' to 'nil' always returns true
   HermesTests/Tests/AppStateFactoryTests.swift:33:44: warning: comparing non-optional value of type 'PlayerViewModel' to 'nil' always returns true
   HermesTests/Tests/AppStateFactoryTests.swift:34:46: warning: comparing non-optional value of type 'StationsViewModel' to 'nil' always returns true
   HermesTests/Tests/AppStateFactoryTests.swift:35:45: warning: comparing non-optional value of type 'HistoryViewModel' to 'nil' always returns true
   HermesTests/Tests/AppStateFactoryTests.swift:82:43: warning: comparing non-optional value of type 'LoginViewModel' to 'nil' always returns true
   HermesTests/Tests/AppStateFactoryTests.swift:83:44: warning: comparing non-optional value of type 'PlayerViewModel' to 'nil' always returns true
   HermesTests/Tests/AppStateFactoryTests.swift:84:46: warning: comparing non-optional value of type 'StationsViewModel' to 'nil' always returns true
   HermesTests/Tests/AppStateFactoryTests.swift:85:45: warning: comparing non-optional value of type 'HistoryViewModel' to 'nil' always returns true
   HermesTests/Tests/AppStateFactoryTests.swift:207:43: warning: comparing non-optional value of type 'LoginViewModel' to 'nil' always returns true
   HermesTests/Tests/AppStateFactoryTests.swift:210:46: warning: comparing non-optional value of type 'StationsViewModel' to 'nil' always returns true
   HermesTests/Tests/AppStateFactoryTests.swift:230:43: warning: comparing non-optional value of type 'LoginViewModel' to 'nil' always returns true
   HermesTests/Tests/AppStateFactoryTests.swift:233:46: warning: comparing non-optional value of type 'StationsViewModel' to 'nil' always returns true
   HermesTests/Tests/AppStateFactoryTests.swift:248:28: warning: comparing non-optional value of type 'AppState' to 'nil' always returns true
   HermesTests/Tests/AppStateFactoryTests.swift:266:28: warning: comparing non-optional value of type 'AppState' to 'nil' always returns true
   HermesTests/Tests/AppStateFactoryTests.swift:286:28: warning: comparing non-optional value of type 'AppState' to 'nil' always returns true
   HermesTests/Tests/AppStateFactoryTests.swift:311:28: warning: comparing non-optional value of type 'AppState' to 'nil' always returns true
   HermesTests/Tests/DependencyInjectionPropertyTests.swift:558:17: warning: variable 'errorMessage' was written to, but never read
   HermesTests/Tests/ImageCacheTests.swift:162:13: warning: initialization of immutable value 'result' was never used; consider replacing with assignment to '_' or removing it [#NoUsage]
   2026-09-17 02:38:59.964 appintentsmetadataprocessor[60760:5087214] warning: Metadata extraction skipped, no AppIntents.framework dependency found
   ```

3. Root-cause fixes applied

   - **Destination selection**

     ```text
     --- xcodebuild: WARNING: Using the first of multiple matching destinations:
     ```

     Exact setting changed: `Makefile` now defines `DESTINATION = platform=macOS,arch=$(shell uname -m)` and sets `COMMON_OPTS = -project Hermes.xcodeproj -destination "$(DESTINATION)"`. The warning's cause is the previously omitted destination while Xcode sees both arm64 and x86_64 variants of the same Mac. Selecting the invoking host's native architecture removes that ambiguity at its source without hard-coding an architecture that could make `make run` unusable on an Intel host. This does not disable a warning or lower a compiler/toolchain strictness setting.

   - **Notification payload captures:** `UpdateCheckerTests` imports the standard `Synchronization` module and records only the tested `Bool` result in Swift `Mutex` values. The prior code transferred a non-Sendable `[AnyHashable: Any]` across an `@Sendable` notification closure. The mutex makes the test's cross-thread state explicit without an unchecked-Sendable annotation or a new dependency.
   - **Vacuous assertions:** `AppStateFactoryTests` and `StationsViewModelTests` replace assertions comparing statically non-optional values with `nil` with direct assertions of initial model state, dependency identity, and loaded station data. No assertion was deleted without a stronger behavioral replacement.
   - **Unused test values:** `DependencyInjectionPropertyTests` now asserts that a successful authentication did not deliver an error message. `ImageCacheTests` still accepts an unsupported data URL, but verifies that any loaded image has positive dimensions.

4. Deliberately left for human

   ```text
   warning: Metadata extraction skipped, no AppIntents.framework dependency found
   ```

   Exact setting changed: none. No App Intents source or framework dependency is present. The candidate workaround, `OTHER_SWIFT_FLAGS = -Xfrontend -disable-autolink-framework -Xfrontend AppIntents`, would change the target's AppIntents framework-linkage behavior. That is a framework-dependency decision, reserved for the human; using it here would mute the processor rather than establish the intended framework dependency. No App Intents build setting or dependency was changed.

   ```text
   HermesTests/Tests/AppStateFactoryTests.swift:240:28: warning: comparing non-optional value of type 'AppState' to 'nil' always returns true
   HermesTests/Tests/AppStateFactoryTests.swift:258:28: warning: comparing non-optional value of type 'AppState' to 'nil' always returns true
   ```

   These two tests are intentionally left unchanged. Exercising the actual `NotificationCenter.default` subscription requires posting a process-global error notification. Every live `AppState`, including `AppState.shared` if another serial test initialized it, receives that notification asynchronously and mutates both its view state and pending-login credentials. The test cannot unregister the production subscriber or completely restore that internal state. Fixing this safely requires an injectable notification center or a production `AppState` design change, both outside this warning-only task and prohibited by the reserved-file boundary. Leaving these warnings is more honest than introducing state leakage or a flaky test.

5. Test coverage ledger

   Every diagnostic-bearing test change is listed below by its original warning location. No row reduces coverage.

   - `HermesTests/Tests/UpdateCheckerTests.swift:131` - `warning: capture of 'receivedUserInfo' with non-Sendable type '[AnyHashable : Any]?' in a '@Sendable' closure [#SendableClosureCaptures]`; before: captured the full notification dictionary and asserted `updateAvailable == true`; after: a `Mutex<Bool?>` captures `updateAvailable` and asserts it is `true`; coverage unchanged.
   - `HermesTests/Tests/UpdateCheckerTests.swift:172` - `warning: capture of 'receivedUserInfo' with non-Sendable type '[AnyHashable : Any]?' in a '@Sendable' closure [#SendableClosureCaptures]`; before: captured the full notification dictionary and asserted `updateAvailable == false`; after: a `Mutex<Bool?>` captures `updateAvailable` and asserts it is `false`; coverage unchanged.
   - `HermesTests/Tests/UpdateCheckerTests.swift:195` - `warning: capture of 'receivedUserInfo' with non-Sendable type '[AnyHashable : Any]?' in a '@Sendable' closure [#SendableClosureCaptures]`; before: captured the full notification dictionary and asserted its `error` value was non-nil; after: a `Mutex<Bool>` captures whether `error` is non-nil and asserts `true`; coverage unchanged.
   - `HermesTests/Tests/StationsViewModelTests.swift:30` - `warning: comparing non-optional value of type '[Station]' to 'nil' always returns true`; before: asserted that `stations` existed; after: asserts that the initial station list is empty; coverage strengthened.
   - `HermesTests/Tests/AppStateFactoryTests.swift:32` - `warning: comparing non-optional value of type 'LoginViewModel' to 'nil' always returns true`; before: asserted the production login view model existed; after: asserts it starts idle and without an error; coverage strengthened.
   - `HermesTests/Tests/AppStateFactoryTests.swift:33` - `warning: comparing non-optional value of type 'PlayerViewModel' to 'nil' always returns true`; before: asserted the production player view model existed; after: asserts it has no song and is stopped; coverage strengthened.
   - `HermesTests/Tests/AppStateFactoryTests.swift:34` - `warning: comparing non-optional value of type 'StationsViewModel' to 'nil' always returns true`; before: asserted the production stations view model existed; after: asserts its initial station list is empty; coverage strengthened.
   - `HermesTests/Tests/AppStateFactoryTests.swift:35` - `warning: comparing non-optional value of type 'HistoryViewModel' to 'nil' always returns true`; before: asserted the production history view model existed; after: asserts its initial history is empty; coverage strengthened.
   - `HermesTests/Tests/AppStateFactoryTests.swift:82` - `warning: comparing non-optional value of type 'LoginViewModel' to 'nil' always returns true`; before: asserted the test-factory login view model existed; after: asserts it starts idle and without an error; coverage strengthened.
   - `HermesTests/Tests/AppStateFactoryTests.swift:83` - `warning: comparing non-optional value of type 'PlayerViewModel' to 'nil' always returns true`; before: asserted the test-factory player view model existed; after: asserts it has no song and is stopped; coverage strengthened.
   - `HermesTests/Tests/AppStateFactoryTests.swift:84` - `warning: comparing non-optional value of type 'StationsViewModel' to 'nil' always returns true`; before: asserted the test-factory stations view model existed; after: asserts its initial station list is empty; coverage strengthened.
   - `HermesTests/Tests/AppStateFactoryTests.swift:85` - `warning: comparing non-optional value of type 'HistoryViewModel' to 'nil' always returns true`; before: asserted the test-factory history view model existed; after: asserts its initial history is empty; coverage strengthened.
   - `HermesTests/Tests/AppStateFactoryTests.swift:207` - `warning: comparing non-optional value of type 'LoginViewModel' to 'nil' always returns true`; before: asserted the production login view model existed; after: asserts its initial username is empty; coverage strengthened.
   - `HermesTests/Tests/AppStateFactoryTests.swift:210` - `warning: comparing non-optional value of type 'StationsViewModel' to 'nil' always returns true`; before: asserted the production stations view model existed; after: asserts it receives `AppState`'s Pandora instance; coverage strengthened.
   - `HermesTests/Tests/AppStateFactoryTests.swift:230` - `warning: comparing non-optional value of type 'LoginViewModel' to 'nil' always returns true`; before: asserted the test-factory login view model existed; after: asserts its initial username is empty; coverage strengthened.
   - `HermesTests/Tests/AppStateFactoryTests.swift:233` - `warning: comparing non-optional value of type 'StationsViewModel' to 'nil' always returns true`; before: asserted the test-factory stations view model existed; after: asserts it receives the supplied mock Pandora instance; coverage strengthened.
   - `HermesTests/Tests/AppStateFactoryTests.swift:248` - `warning: comparing non-optional value of type 'AppState' to 'nil' always returns true`; before: asserted the production factory returned an instance; after: unchanged and reserved for the human because an isolated notification assertion requires a prohibited `AppState` design change; coverage unchanged.
   - `HermesTests/Tests/AppStateFactoryTests.swift:266` - `warning: comparing non-optional value of type 'AppState' to 'nil' always returns true`; before: asserted the test factory returned an instance; after: unchanged and reserved for the human because an isolated notification assertion requires a prohibited `AppState` design change; coverage unchanged.
   - `HermesTests/Tests/AppStateFactoryTests.swift:286` - `warning: comparing non-optional value of type 'AppState' to 'nil' always returns true`; before: asserted a failure-configured test factory returned an instance; after: asserts the injected mock is retained, the current view is login, and credential restoration is absent; coverage strengthened.
   - `HermesTests/Tests/AppStateFactoryTests.swift:311` - `warning: comparing non-optional value of type 'AppState' to 'nil' always returns true`; before: asserted the preconfigured-stations test factory returned an instance; after: asserts it retains the supplied mock and loads two configured stations into `StationsViewModel`; coverage strengthened.
   - `HermesTests/Tests/DependencyInjectionPropertyTests.swift:558` - `warning: variable 'errorMessage' was written to, but never read`; before: captured an error payload without asserting it; after: asserts `errorMessage` is nil for successful authentication; coverage strengthened.
   - `HermesTests/Tests/ImageCacheTests.swift:162` - `warning: initialization of immutable value 'result' was never used; consider replacing with assignment to '_' or removing it [#NoUsage]`; before: only awaited the data-URL load without inspecting its value; after: still accepts nil but asserts positive dimensions if an image is returned; coverage strengthened.

   Supporting test-only code does not suppress diagnostics: `UpdateCheckerTests.swift:7` imports the standard `Synchronization` module for the three mutex-backed captures. It does not change notification names, test operations, or completion timing.

6. Validation and state protection

   - Baseline `make test` passed 145 XCTest cases plus 282 Swift Testing tests: 427 total, 0 failed. This is one higher than the supplied 426 baseline; the captured baseline log itself records 145 plus 282.
   - Final exact `make` exited 0 with 0 warnings in `make-final.log`.
   - Final exact `make test` exited 0 with 6 displayed warnings: the App Intents metadata warning for each target and each of the two deliberately reserved AppState diagnostics rendered twice by the compiler. No destination or other Swift source diagnostics remain.
   - Final `make test` passed 145 XCTest cases plus 282 Swift Testing tests: 427 total, 0 failed. Test-count delta from the captured baseline is 0.
   - No screenshot or recording is required: this build and test-source cleanup has no user-visible surface.
   - The protected state manifest is unchanged before and after:

     ```text
     c7615ff7c31545e8dd4f7c2ddac9b11cfa1d4ee8d3857d916ab66d4be4c0780d  /Users/stepblk/Library/Application Support/Hermes/history.savestate
     7c2e90ec2b9630130c3d0f9db3d38963399ea7aa5f907bec741bf3c6e901f89b  /Users/stepblk/Library/Application Support/Hermes/station.savestate
     /Users/stepblk/Library/Application Support/Hermes/history.savestate 2884 bytes
     /Users/stepblk/Library/Application Support/Hermes/station.savestate 618 bytes
     ```
