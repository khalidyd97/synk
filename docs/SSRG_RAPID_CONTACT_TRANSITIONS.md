# Rapid slide-to-note transition fix — 2026-10-28

User identified13-lane play. Read-only inspection found one installed lv13 chart (239notes,71slides) and source speed2.0. No phone chart, draft, audio or preferences were changed during diagnosis. Tests use an isolated desktop profile and a local uncommitted copy of that chart.

## Reproduced failure

A short slide's finger is released, then Android reuses the same physical finger index for the following press before the next gameplay update. The old pointer dictionary entry was replaced, discarding the release and treating the new contact as the previous slide's owner. The old slide could expire as MISS; same-lane transitions could also consume the fresh tap's frame gate.

The new actual-main regression test failed twice before the fix (old release/tap pair not preserved, then old slide expired) and passes afterward.

## Changes

- Preserve each queued contact separately when a physical finger index is reused. A physical-to-internal mapping routes later movement/release to the current contact. Old releases remain available until consumed; start/restart/pause clear the map.
- Resolve pending head presses chronologically per distinct contact, using the existing captured press timestamp and nearest eligible note in that contact's routed channel. Two genuine presses accumulated in one delayed frame no longer collapse into the last lane winner. Each physical press still scores at most one head, and repeated update calls cannot duplicate it.
- Evaluate an owned terminal release from its preserved contact snapshot, using the captured release time/position. A release and a new press may both score within one frame because they are separate physical events. Held automatic checkpoint judgments retain their per-channel frame gate.
- Continue existing line-crossing timing, touch rectangles, cancellation safeguards and rear deadlines. No blanket timing widening, audio offset change or automatic slide completion.
- Debug APK logs a compact local SSRG_SLIDE_MISS context (chart time, node time, started/checkpoint state, internal owner and contact count) only on a slide miss. It sends nothing externally and adds no UI; it supports exact-note diagnosis if a device-only failure remains.

These are SYNK event-batching/identity fixes, not a claim that every original Unity touch path is identical.

## Validation

Passed actual-main cases: release then new press in another lane, full short slide plus following same-lane tap accumulated into one delayed frame, no later old-slide expiry, no duplicate scoring, touch-band re-entry, shared-lane lift protection, expiry without returned contact, quick-tap timing, re-grab/cancel, crossing fingers, full SSRG integration, entrance and gameplay extras. Earlier continuous30/60/120FPS zigzag/hold tests also pass.

The installed chart's71slides were additionally followed independently using the actual straight projected connector/bar intersection, at source speed2.0, with40ms simulated following delay, two touch heights and up to0.45lane horizontal variation: zero missed slides in those isolated simulations. This does not establish full-chart human performance or device touch accuracy; it helped narrow the investigation to contact transitions.

Fresh APK: builds/android/slide-contact-identity-20261028/SYNK.apk. Signature/device transfer/replacement installation follow the standing workflow. No device game launch, uninstall or data clearing; no GitHub release requested.
