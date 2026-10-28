# SSRG slide autoaim and multi-finger integration — 2026-10-28

## Applied

Only imported SSRG manual play uses the new router. Normal SYNK input, recorder authoring, charts/drafts and visual customization remain intact; special-note effects remain excluded.

- Collect the frame's touch events before judging, preserving active touch creation order. Begin/move/stationary/end states route to shared source channels; no permanent chain-exclusive finger locks.
- Build calibrated sixth-power projected touch rectangles using logical212x116 note dimensions: width233.2q; middle/end height290q. User note-size and 4/7/13 channel width do not enlarge autoaim.
- A moving/stationary finger can autoaim to its chain's next unjudged node only while the source middle window is eligible. Other fingers use their own physical channel; they may re-grab through that channel under existing node deadlines.
- Source global touch bounds precede channel/side-channel fallback. Began input can select an ordinary/head autoaim rectangle; tap heads need Began, sustained heads also accept channel movement.
- Use the shared channel winner on a successful node and remember that finger for subsequent moving autoaim. One successful judgment per channel per frame prevents a checkpoint loop from consuming a whole dense section in one update.
- Beams follow routed channels rather than a finger's unassisted physical lane.
- During the silent new-game approach, input states still advance, avoiding a stale Began held until the first note. Notes retain their original timestamps.

## Deliberate adaptations and evidence limits

Original static code clears a departed channel without checking whether a crossing finger has just acquired it. SYNK adds an identity guard to that movement cleanup so crossing slides do not erase one another. This is an intentional protection, not a claim of exact original bug parity. Shared-channel ending behavior retains the traced channel state model, while OS cancellation cannot award a successful release. SYNK also explicitly clears an aim when leaving the recovered global bounds instead of reproducing the source's stale-state edge.

Godot events are accumulated until the gameplay update; the source gathers Unity touches once per update. The frame consumption token combines the engine frame with judgment time for deterministic desktop test simulation. Native source timing can be overridden online; the original application has not been run for live comparison. Calibration/tempo-specific arbitration outside the packaged defaults is not claimed identical.

## Validation

- Router unit tests: source geometry, rect boundaries, 4/7/13 fallback, above-collider autoaim, owner-only moving aim, creation-order arbitration, channel transitions, cancellation, frame consumption and global exit.
- Actual-main tests: two crossing slides with reversed numeric finger IDs, aim into neighboring physical channels, unrelated new finger isolation, beam alignment, overlapping checkpoints, and shared channels across successive frames.
- Existing full SSRG input, sustain re-grab/release, entrance, screen fitting, shared gameplay and restored recorder checks pass. The culling pixel test hides the requested entrance veil only while checking distant-note shader culling.
- Supplied239-note13-lane chart and audio: desktop autoplay through12seconds after the real countdown/approach, zero backward visual-clock steps. This checks integration/clock behavior, not manual finger accuracy or phone frame rate.

Source evidence: [slide rectangles](SSRG_SLIDE_AUTOAIM_EVIDENCE.md), [touch arbitration](SSRG_MULTIFINGER_EVIDENCE.md). The tests separately distinguish recovered rules from the protections above.

Fresh APK: builds/android/ssrg-slide-autoaim-20261028-0915/SYNK.apk. APK v2/v3 signatures verified with the existing Godot signer. Samsung RZCW10J7R7A was authorized; APK copied to Downloads/SYNK-slide-autoaim.apk and installed successfully using a non-incremental replacement. No app launch, manual phone testing, uninstall or data clearing performed. No GitHub release published.

