# Pre-change history archive fixture provenance

This fixture is intentionally fixed input for compatibility tests. It was
generated before any production reader change, from commit `3030c10`.

- Source blob: `Sources/Swift/Models/Song.swift`
  `2e6199d6bf26be4aa5f9916113092e807bf0e997`
- History writer blob: `Sources/Swift/ViewModels/HistoryViewModel.swift`
  `48fe211bf293f90698b220f52bc867a0846b2cfd`
- Encoder invocation:
  `NSKeyedArchiver.archivedData(withRootObject: [second, first], requiringSecureCoding: false)`
- `first`: token `historical-song-one`, `allowFeedback == false`
- `second`: token `historical-song-two`, `allowFeedback == true`
- Output: `history-prechange.savestate`, 681 bytes
- SHA-256:
  `08fed3686e790b28c72011b0aebe5e96c0904d24e1a97c6a02f8bb458a456fef`

The generator ran in an isolated `/tmp/hermes-tests.*` home. The permanent
test consumes this checked-in binary fixture through a fresh
`HistoryViewModel`; it never re-encodes the fixture through changed code.

## Primitive boolean history archive fixture provenance

`history-primitive-bool.savestate` is a fixed input for the second supported
on-disk representation. It was generated in an isolated
`/tmp/hermes-tests.*` home by a test-only `NSCoding` object that encoded
`allowFeedback` with `coder.encode(allowFeedback, forKey:)`, then mapped that
object class to `Hermes.Song` in the keyed archive. It did not invoke the
production reader or modify the production writer.

- `true` and `false` values were encoded in one array.
- Output: `history-primitive-bool.savestate`, 516 bytes
- SHA-256:
  `af7ff68b2387beaa4e291d16e35c61454f772890a31a4d1d35b9256413167097`

The permanent compatibility test feeds these bytes only to a fresh
`HistoryViewModel` and asserts the resulting `Song.allowFeedback` values. It
does not call an unarchiver directly.
