# Frame pacing, audio sync and touch feedback — 2026-10-28

## Changes

- Background particles reuse fixed-capacity MultiMesh batches rather than clearing/rebuilding ImmediateMesh surfaces every frame. Source emission, progress, tapered geometry, textures, colors and customization are retained. No effects are dropped in dense sections. Shader builds each near/far edge from instance data; pause freezes the existing buffers.
- Repeated identical score-font color overrides are avoided, reducing unnecessary UI invalidation.
- Audio output latency is cached during loading, resume and calibration entry, instead of queried during every playback frame. If the audio route changes mid-song, pause/resume refreshes the hardware latency; the existing user timing/headset offsets remain in force.
- Visual interpolation is bounded relative to heard audio (25ms lead/35ms lag under advancing samples), so stale mixer samples cannot let notes run arbitrarily ahead. Explicit seek/reset handling and chart timestamps remain intact. Pause and zero pitch do not advance the interpolated clock.
- Existing Audio Sync helper uses the same heard-audio calculation as gameplay, filters duplicate/synthetic taps, and enables its suggested delay only after8 sufficiently consistent taps (median absolute deviation <=35ms). Manual delay remains available; no automatic preferences changes from an unreliable estimate.
- SSRG sustain feedback uses the existing receptor artwork: amber while detached but recoverable, a short cyan ring on re-grab, original hit flow while attached. Completion/miss retires the marker; pause freezes it, new runs clear it, and Hit flashes intensity is respected. Fixed gold bar remains unchanged. These are touch-status cues, not original special-note effects.

## Evidence and checks

Controlled same-process CPU test, deterministic seed73 and31 identical particles,600 alternating renderer samples/100warmup:

| Background render CPU | Previous | Reused batches |
| --- | ---: | ---: |
| Median |260us|180us|
|95th percentile|323us|227us|

This is approximately30% less CPU work in this one component. The broader section profile remains noisy, and this does not establish phone FPS or eliminate all frame spikes. Desktop supplied-chart playback with screenshots still reports process p50 37.564ms/p95 390.224ms. GPU/OS stalls and the screenshot workload are not isolated by that run; stable60FPS is not claimed.

Tests passed: source profiles/count bounds/pause; fixed batch identity/capacity and actual graphical near-edge geometry; heard-position/pitch math; simulated ten-minute jitter/drift and stale mixer; sync-screen duplicate suppression and quality gate; feedback colors/lifetime/pause/cleanup; gameplay entrance; SSRG actual-pointer/full integration and source animation lifetimes; restored recorder and rendered alignment. Headless dummy renderer does not retain GPU instance values, so the near-edge buffer readback assertion runs with the graphical renderer.

The supplied239-note13-lane chart and audio import/play through12seconds after the real countdown and silent approach, with zero backwards visual-clock steps. Desktop audio driver falls back to dummy output; audible sync and real touch feel require the user's device test.

## Build and delivery

Fresh APK: builds/android/pacing-sync-feedback-20261028-1040/SYNK.apk. APK v2/v3 verified with existing signer SHA256 c9e92947fba79611032b76126c01469c7ded8963d63f41915b7d1ba8791bd467. Authorized Samsung RZCW10J7R7A received Downloads/SYNK-pacing-sync-feedback.apk; non-incremental replacement installation returned Success. No phone launch, uninstall, data clearing or manual device testing. Source pushed on codex/ssrg-implementation; no release published.

Profiling tools: tools/profile_gameplay_sections.gd uses the supplied Desktop1004_13.seq fixture. tools/profile_background_batches.gd accepts a saved baseline script path after --; save the prior scripts/ssrg_background.gd from commit22c64a2 to an ignored local file to reproduce the same-process comparison.
