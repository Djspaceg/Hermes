# getStation extended response capture

## Outcome

LIVE: The requested feedback-row field list was not captured. The one
authorized `station.getStation` request was never started because
`station.savestate` shrank from 611 bytes to 505 bytes after app launch.

## Cause

LIVE: The protected-state safety condition required stopping before capture.
INFERRED: `Sources/Swift/MinimalAppDelegate.swift:71-73` saves playback state
when the app resigns active; `PlaybackController.swift:449-450` delegates to
the state store, whose `save` serializes a station to `station.savestate`
(`PlaybackStateStore.swift:58-66`). That is a possible persistence mechanism,
not a proven explanation for the observed shrink.

## Confidence and falsifier

Confidence: MEDIUM, capped because the authorized live response falsifier did
not run.

Falsifier: NOT RUN. The one redacted
`station.getStation(includeExtendedAttributes: true)` call was withheld after
the protected station-state file shrank. It produced no payload, so there is
no LIVE answer to whether a feedback row contains any per-recording identifier
beyond `feedbackId`, `songName`, and `artistName`.

## Recommendation

No deletion-behavior change is proposed. Preserve the existing fail-closed
behavior.

## Decisions to evaluate

None; default taken: stop immediately on the protected-state shrink.

## Open questions

Why launch caused the observed state rewrite; default taken: no additional
instrumentation or launch in this task.

## Evidence

- `CAPTURE-EXECUTION.md`: guards, launch identity, authentication samples,
  protected-state measurements, and shutdown.
- `FINDINGS.md`: consolidated outcome and the capped conclusion.

## Residuals

The feedback-row field list remains unknown. No extended-response artifact
exists, and no fix was written.
