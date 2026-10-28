# Long slide connector judgment fix — 2026-10-28

The user reports long slide connector judgment feels off. Continuous actual-main simulation reproduced two integration behaviors that made the visual crossing disagree with scoring:

1. Held middle nodes were automatically consumed as soon as their200ms front window opened. Held ends were automatically consumed at the300ms front edge, which also produced GOOD on an otherwise accurate sustained hold.
2. A terminal End-state was always forced to GOOD, even for a captured release exactly on time.

## Applied behavior

- Automatic held/moved/began sustain-node judgments wait until the connector puck or tail reaches its chart timestamp. The existing late deadline still allows recovery after a late frame or re-grab.
- A deliberate terminal release can still be accepted up to225ms early, but its grade uses the captured release error and existing timing thresholds. An on-time release can earn internal PERFECT (displayed S·PERFECT); a220ms early release remains GOOD.
- Middle-node grade inheritance, rear deadlines, source touch rectangles/autoaim, frame channel gates, chart timestamps, artwork, recorder, customization and special-note exclusions remain unchanged. No miss strip returns.

These are explicit SYNK playability adjustments to the recovered source-state behavior, not newly established original-game parity. Existing evidence of original early eligibility and forced Good is retained in the research reports.

## Validation

Six-second full-width zigzag slides and stationary holds are simulated continuously at30/60/120updates per second. Every connector waits for its own crossing; all four judgments (head, two connectors, tail) are correct, with no early completion or phantom GOOD/MISS. Additional tests cover deliberate early release, precisely timed release processed120ms later, cancellation, too-early release, late re-grab, expired-chain miss fan-out, crossing fingers, shared channel consumption, dense tap timestamps and full SSRG integration. All passed.

Fresh APK: builds/android/long-slide-judgment-20261028/SYNK.apk. Existing signature verification and authorized-device replacement installation apply. No app launch, uninstall or data clearing; no release publishing.
