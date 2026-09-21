# Capture execution record

## Outcome

The authorized extended response capture did not run. The process was
stopped before the one-shot selector was invoked because the protected
station state shrank after launch.

## Live record

- The pre-launch `pgrep -x Hermes` and `pgrep -x xcodebuild` checks were
  clear.
- LaunchServices started
  `Hermes-getstation-field-capture/.capture-build/Build/Products/Debug/Hermes.app`.
  PID 40371 matched that exact executable path and remained alive after the
  launch shell exited.
- Two read-only `isAuthenticated` samples on that PID returned `YES`; no
  early unauthenticated conclusion was made. The loaded-station count was 95.
- Before launch, protected state sizes were history 9602 bytes, station 611
  bytes, and artwork cache 1806 bytes. After launch and before the request
  selector, they were history 11466 bytes, station 505 bytes, and artwork
  cache 1806 bytes. The station file therefore shrank.
- No capture selector invocation, `station.getStation` request, retry,
  account write, station edit, preference write, or capture-primitive
  Keychain access occurred.
- PID 40371, the process started for this task, was terminated immediately
  after the safety stop and was confirmed down. The three protected files
  remained present after shutdown; their final sizes were 11466, 505, and
  1806 bytes respectively.

## Scope

No source fix was made. The expected
`getstation-response-extended-redacted.json` file is absent.
