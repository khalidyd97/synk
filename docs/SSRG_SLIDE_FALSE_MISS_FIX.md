# Slide false-miss recovery fix — 2026-10-28

The user's repeated slide misses were reproduced in actual-main input tests, not just inferred from the rules. Both cases failed before the changes and pass after them.

1. A started slide's still-down finger moves above the ordinary channel band, then returns before the next connector. The old channel becomes Lost/Idle. The moved/stationary parser required a pre-existing active channel, so it never reattached the finger; the next node eventually missed despite valid returned contact.
2. Two fingers share a lane and one lifts. Its End branch unconditionally cleared the lane, even if the other finger currently held it. The remaining finger could then be left in the same unrecoverable Idle state.

## Changes

- Mark fingers associated with an active started sustain during routing. Such a still-down finger can re-enter a valid physical/assisted channel as HELD after a gap. It does not become BEGAN/MOVED and therefore cannot generate a fresh tap/long head. Global bounds, original touch geometry and real node deadlines are retained.
- End/cancel clears only a channel belonging to that pointer or an unowned channel. It cannot erase another finger's live contact. This extends the existing crossing-finger movement identity guard to releases.
- Normal SYNK and recorder input remain separate. No additional miss grace, automatic completion or timing-window widening was added. An unreturned finger still misses after the genuine checkpoint deadline; canceled touch does not award a release hit.

These are deliberate SYNK protections beyond the original shared-channel quirks documented in SSRG_MULTIFINGER_EVIDENCE.md. Original disassembly evidence remains unchanged.

## Validation

Actual-main tests reproduce both failures, verify recovery after returning, verify continued contact through another finger's release, and verify two remaining nodes still MISS when contact never returns. Router, continuous full-width zigzags/holds at30/60/120FPS, re-grab/release/cancel, crossing fingers, full SSRG integration and tap timestamp regressions pass.

Fresh APK: builds/android/slide-contact-recovery-20261028/SYNK.apk. Build/signature/device transfer and replacement installation follow the standing workflow. No phone game launch, uninstall, data clearing or release publication.
