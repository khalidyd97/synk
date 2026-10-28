# Audio/judgment and choppy-motion regression fixes — 2026-10-28

User reports speaker audio/judgments out of sync and then clarifies choppy note movement. No speculative Bluetooth delay or device sync offset is applied.

## Regressions fixed

- Source-style frame batching was overwriting a Began with a same-frame drag or release. Preserve the original press position/time until the batch is consumed; a quick down/up scores once, while OS cancel does not create a hit.
- Capture the interpolated heard-audio timestamp when an input event is received. Grade heads at the press time and terminal releases at release time, rather than the later gameplay update. Replay recording retains this timestamp; replay injection uses the recorded time.
- Evaluate a pending head's projected autoaim rectangle at its press timestamp. In a dense same-channel section, select the head nearest that press instead of allowing an older still-open late window to consume it. This is an intentional SYNK usability adaptation, not a claim about original SSRG note traversal parity.
- Keep the smoothed, bounded audio-linked render clock. An intermediate local APK followed the audio sample directly; it is superseded because direct sample jitter can make note movement choppy. Judgments retain precise input timestamps independently. A jitter simulation verifies that visual step variation is less than one quarter of raw alternating mixer sample variation.
- Background geometry now sends one packed buffer upload per texture batch, replacing three rendering-server calls per particle. Writable packed buffers are unshared while updated. The original source near/far edges, colors and fixed capacity are retained and graphically checked.
- Correct the timing-offset hint: existing positive values advance notes, negative values delay them. Saved values are not inverted or changed.

## Validation and limits

Passed: quick tap released before render, same-frame touch movement, delayed-update grade/time-report preservation, canceled press, dense nearest-beat targeting, router/shared-channel, crossing slides, re-grabs/end releases, entrance, source/full integration, jitter/drift clock simulation, gameplay extras and actual graphical background buffer geometry. The legacy extras test now ignores shader materials that have no clip_z uniform instead of attempting float(null); its actual clipping/isolation assertions still pass.

Controlled background CPU run, same process/seed/31 particles: original ImmediateMesh p50/p95 263/463us versus bulk batches141/287us. This is a component CPU measurement; phone frame pacing is not measured. A desktop vsync-only experiment did not improve the supplied-chart run, so frame-rate preferences remain unchanged. The installed APK archive was inspected: the main compiled script differs between builds; an old export was not the cause.

Supplied chart/audio desktop playback covers the real countdown/approach and12seconds of13-lane play. Desktop output is dummy audio, so audible sync is not validated. No game launch or manual testing on the Samsung was performed.

Fresh final APK: builds/android/timing-motion-fix-20261028/SYNK.apk. Signature verified v2/v3 with existing signer c9e92947fba79611032b76126c01469c7ded8963d63f41915b7d1ba8791bd467. The earlier audio-judgment-fix APK was installed successfully, but the Samsung then disconnected. Normal ADB reconnect returned no devices; the final motion/bulk-buffer build cannot yet be transferred or installed. No charts/drafts were cleared. No release published.
