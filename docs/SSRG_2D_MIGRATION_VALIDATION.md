# SSRG 2D migration corrections and validation

Date: 2026-10-27.

## Confirmed old-renderer issues fixed

- Late note popping: shader-projected sprites and ribbons retained CPU bounds around their obsolete raw60-unit timing positions. The orthographic canvas is only9.79 units long, so culling could hide notes that should already be visible. Moving note geometry now has conservative culling bounds covering its shader displacement. A GPU readback test proves an early approach note is actually drawn at raw progress.75 (drawn progress.17798).
- Finger beams: old58-unit rectangles neither tapered nor converged with the2D road. Their mesh now spans the source apex to the bottom of the judgment area, with each cross-section converging toward the same apex as the notes. Width and snapped lane centres follow the selected4/7/13-lane or normal10-lane layout, and old perspective rectangles are restored for recorder use.
- Duplicate slide glow: obsolete SYNK slide-hit beam overlays no longer appear over SSRG's own sustain effects.
- Held ribbons: clipping now uses the shader-projected judgment plane. Applying the old raw timing-Z comparison after nonlinear projection could leave a strip below judgment. Whole note caps use their centre for retirement rather than cutting through their old quad vertices.
- Pause: displayed SSRG motion retains its visual clock instead of jumping to the unsmoothed judgment/audio clock.
- Countdown: notes and receptor indicators remain hidden during a new-game countdown.
- Background haze: projected rail edges now use the2D rail positions rather than an old parallel60-unit road.
- Multiplier wave: follows2D stage depth and taper instead of travelling along the old perspective track.
- Postprocessing: SSRG sprites bypass the old fullscreen3D bloom/entry shadow and multisample resolve. The original sprite already contains its glow/soft outline. Recorder restores its original postprocessing and antialiasing.
- Hit texture alpha is respected rather than treating the complete texture rectangle as opaque additive content.

## Supplied chart/audio test

The user-supplied1004_13.seq and1004.a.bytes.ogg were imported through the normal SSRG library storage/launch flow into an isolated desktop profile. No user charts or drafts were replaced. Imported239 playable notes,13 lanes,BPM122. Audio decoded length61.2295 seconds. Full automated playback reached61.2209 seconds (within9ms of audio end), score355000, all239 notes loaded, zero backward displayed-clock steps. This is automated playback, not a physical touch test or comparison against the running reference game.

After authorized sign-in, an additional12-second normal-screen playback succeeded and screenshots show the gameplay UI with imported notes/effects. Credentials were supplied only via temporary process environment; no password is stored in this report or committed test code.

This desktop reports32Hz, and the existing match-display setting capped the run at32fps. Frame-time outliers occurred; this validation does not claim60/120Hz or hitch-free phone performance. Local full-run metrics and screenshots are retained under .tools/1004-playback-report.json and .tools/1004-ssrg-*.png. The real audio/chart files are not included in the source commit or APK.

## Regression checks

- test_ssrg_render_alignment.gd: actual early-note GPU visibility, conservative render bounds, beam width/apex and lane alignment for4/7/13 keys, outer/central hit-flash alignment, held-ribbon clipping below judgment, pause clock, countdown hiding, recorder beam/postprocessing restoration.
- test_ssrg_reference_motion.gd: original sixth-power position/size curve, timing/speed and touch mapping.
- test_shared_ssrg_gameplay.gd: shared renderer and recorder isolation.
- test_recorder_restored.gd: recorder controls/history/straightening remain intact.
- test_ssrg_music_start.gd: chart start-marker/audio-offset handling remains unchanged.

Desktop checks passed. Android signature and transfer status are reported with the build; no phone installation or launch is authorized by this workflow.

## Later source-art corrections

SSRG_STAGE_VIDEO_MATCH.md supersedes the initial lane-width beam estimate, generated receptor art/fade and synthetic floor. It documents the correct APK rail image, native295-unit beam polygon/alpha strip, original guide sprite padding and RenderNoteGuide fade.
