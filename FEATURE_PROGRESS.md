# SYNK feature continuation

Authorized: continue the previously proposed features one by one. Build APK, never install/push to phone. Preserve current star hit effect, mobile icon, MR vocal reduction, recorder speed and menu layout.

Already complete: autosave/recovery, multiple chart versions, chart sharing, customizable effects.

Remaining:
- [x] Range transformations: mirror, shift timing, shift lanes, repeat; one undo per operation; reject overflow atomically. Test: test_range_transform.gd PASS.
- [x] Chart validation: report overlaps, fast slide jumps, song overflow; jump to problems without changing notes. test_chart_audit.gd PASS.
- [x] Editor overview strip: whole-song density, section markers, viewport and playhead; tap/drag to seek. test_chart_audit.gd PASS.
- [x] Metronome and beat offset: save per-song grid offset, use it consistently for snapping/beat lines/clicks. test_beat_grid.gd PASS.
- [x] Practice mode: chosen time range, slower playback, repeat/restart; never write practice results as best scores. test_practice_timing.gd PASS, including UI speed selection.
- [x] Timing feedback: signed Early/Late feedback and results graph; exclude autoplay/practice from best records. test_practice_timing.gd PASS. Also fixed fractional accuracy division.
- [x] Focused regression tests, visual QA, final APK export and verification. builds/android/SYNK.apk signed and verified; packaged feature scripts checked. Never installed on phone.

Status: COMPLETE. Regression checks passed: core, editor clipboard/recording, drafts/versions/sharing, recorder speed, MR, effects, screen polish and lobby flow. Visual QA completed for overview/range selection, Arrange, Check, Grid, Practice and results timing graph.

Access: Editor → MORE → Arrange / Check / Grid / Practice. TRANSFORM also appears in the range inspector. Overview is the narrow ALL strip beside the timeline. Early/Late appears during manual play; results → TIMING shows the graph.

Automatic follow-up resume-synk-features is no longer needed after completion and should be paused. Do not start additional feature work without a new user request.

## Additional user requests

- [x] Ghost recording: saved notes approach the hit line at reduced opacity; new take is separate; saved on/off toggle; Arrange retains normal editable notes.
- [x] Difficulty analysis: estimated level, active/peak note density, chords, note types and slide movement under MORE → Analyze.
- [x] Section bookmarks: named playheads/ranges per song, persisted in preferences; jump and delete; markers on timeline/overview.
- [x] Group movement: RANGE → MOVE GROUP → drag X across lanes / Y through time; one undo; paths/checkpoints preserved; whole-group boundary clamping; selected identities survive overlaps at the destination.
- [x] Smooth song browsing: finger-following carousel, momentum, edge resistance, canceled touch handling, reused cards, pending selection tracking, and layered background/palette crossfades.
- [x] Final combined regression, visual checks and APK export for these additional requests. APK signed and verified; no phone installation.

Additional requests COMPLETE. Creator tools, smooth carousel, original carousel flow, clipboard/recording, lobby, range transformations, practice/timing, drafts/sharing, recorder speed and MR tests passed. Visual checks completed for ghosts, analysis, bookmarks and carousel motion. APK: builds/android/SYNK.apk.

## Scoped tools and preview controls

- Preview waveform and preview button removed from song selection. Saved Song previews toggle is in Settings.
- MORE renamed CHART TOOLS. Categories: THIS CHART, THIS SONG, VERSIONS, SHARE. Current song/chart version or shared song scope is explicit and updates when changing versions.
- Global visual effects have a dedicated Settings screen without chart navigation. Global metronome toggle moved to Settings; first-beat grid offset remains song-specific.
- Tests: test_tools_scope, custom effects, workbench/drafts, carousel, creator tools and practice/timing PASS. Visual QA passed. Updated APK exported; no phone install.

## Final settings ownership (supersedes earlier scope descriptions)

Chart timing, BPM, Verse 2/Bridge sections and bookmarks now belong to each chart version in `chart_settings`. They save/recover/export with notes and participate in undo/redo. Legacy shared timing/bookmarks are migrated as defaults. Settings-only edits now invalidate autosave hashes. Published playback uses saved settings; editor tests/practice use draft settings. Automatic recovery cannot overwrite a dirty in-memory take.

Song-wide: source audio, title, album, cover. Global Settings: device calibration, note appearance/speed, visual effects, preview audio, metronome; Editor Prefs covers MR, recording speed, ghosts and alignment guides. Transport/selection/zoom/practice controls remain temporary session tools. See SETTINGS_SCOPES.md.

COMPLETE. Regression: chart_settings, tools_scope, creator_tools, clipboard, beat_grid, workbench, practice/timing, carousel, recording speed, range transformations, effects, MR, core and screen polish PASS. Visual QA passed. Updated APK signed and verified at builds/android/SYNK.apk; no phone installation.

## Recorder sessions and note sizing

Implemented punch-in Layer/Replace, loop-take banking (32 attempts), audible 0–4 bar pre-roll, instant review/retry/undo, Free/Soft/Strict quantization, in-recorder correction, type passes and locks, subdivision rhythm guide with separate volume, take comparison/splicing, and recording quality checks. Recorder pause now resumes/retries/reviews recording instead of returning to the lobby. Empty replacement attempts preserve the chart. Session configuration stays frozen across loop attempts. See RECORDER_WORKFLOW.md.

Added independent global Note Size (60–125%) and Hold Trail Width (30–150%) under Settings → Visual Effects, with live preview and reset. These affect visual meshes, release rings/flick arrows and recorder ghosts without altering timing, lanes, chart data or hit detection. Slide widths remain unchanged.

Focused recorder-workflow and note-mesh tests PASS; regression checks cover speed, clipboard, beat grid/metronome, settings scopes, chart settings, customizable effects and core. Setup, take review and note-sizing settings visually verified.

## Supplied lobby artwork motion

The SVG lobby design now has independently animated equalizers, traveling neon rim traces, Play triangle glint, three Create Chart faders, sequential chevrons and a rotating settings gear inside its orb. Entrances are staggered; touch/focus animate the lighting without changing the button hit rectangle. Labels remain stationary and the logo does not pulse. Derived assets preserve the original supplied SVGs. Motion stops when the lobby is hidden. See tools/lobby_ui/MOTION.md.

Restored the original 60 FPS animated logo to the gateway. Replaced its geometric background with a clean plate edited from the supplied reference image; removed baked-in logo/buttons/text and reconstructed those regions. Omitted old procedural spotlights to preserve the reference lighting. Both edge flares remain visible across landscape aspect ratios. Logo animation stops when hidden and never changes scale. Reference/background, logo-frame, hidden-clock, navigation and compact-layout checks PASS.

## Reference song selection and results screens

Replaced the cover carousel with the requested vertical list and selected-song panel, rounded cards, cyan selection, artist search, favorite/recent/new filters, preview meter, saved difficulty selection, per-chart score/rank and gradient Play. Original charts remain available; Hard is an additional saved version without shifting prior indices. Rows reuse nodes; touch scrolling has inertia and cancellation.

Rebuilt results around the supplied rank-ring/score/stat-card/judgment-bar/accuracy-graph design. Added actual performance telemetry and separate note-head totals; preserved timing, Auto Play and practice handling. Song List returns directly to selection; Next Song waits for the next playable chart and cancels when navigation changes. See docs/SONG_SELECTION_AND_RESULTS.md. Targeted UI/workflow tests and core/settings/draft/practice/gateway regressions PASS; desktop and compact screenshots visually checked.


## Reference chart library

Replaced the cover grid with the approved song-list and selected-chart workspace design. Added real chart-version rows, saved/draft/live-edit status, artist and version search, In progress/Ready/Recent filters, actual note-density bars and note/hold/flick totals. Record continues the chosen chart and recovered draft; Edit opens the selected version; New opens an unused version in the editor. Async launches disable duplicate actions and cancel when selection/navigation changes. Manage deletes only the selected version and draft; whole-song deletion also removes version and draft files. Reuses list rows and shared touch inertia, rounded artwork, screen fades, animated selection and separate Record/Edit gradients.

Reference chart-library workflow tests, screen-polish integration, compact layout and screenshots checked. See docs/CHART_LIBRARY.md.


## Equal lane pads and stationary hold preview

All ten lanes now divide the complete highway width equally, including the outside lanes. Recorder dividers extend across the full judgment pad; finger illumination uses one lane width. Touch projection resolves the full pad surface, including its near/far corners and exact outer rails, while preserving the approach area and existing gesture coordinate contract.

Active recording previews extend from the song clock even without pointer motion. Only the visible time window is meshed, so long holds and slides remain visible at the judgment bar without changing captured timing, gesture classification or saved notes.

Equal-width projection, full-pad recorder/gameplay input, exact outer edges, multiple camera angles and viewport sizes, stationary 60-second holds, stationary slide tails and cancellation checks PASS. Recorder workflow, note sizing/trail widths and core regressions PASS.


## Rounded lobby buttons

Replaced the active angled metal frames with native dark rounded plates, thin cyan/violet outlines and inset icon tiles matching the new song-library/results theme. Settings uses a matching rounded tile. Preserved independent equalizer strips, rounded-rim light chases, sequential chevrons, Play glint, chart faders, rotating gear, hover/touch feedback and staggered entrances. Captions and hit rectangles stay stable, and hidden animations stop. Logo/background unchanged. Motion/navigation integration tests PASS; desktop and compact screenshots visually checked.


## Rounded Settings redesign

Rebuilt Settings with the new dark starfield/rounded-panel theme, persistent Gameplay/Audio & sync/Visual effects/Editor category rail, large 72-unit steppers, animated pill switches, selectable note-shape tiles and a gradient audio calibration action. Category transitions fade and slide; hover/focus/touch and selected-state lighting ease independently. All categories scroll with touch inertia and reject accidental preference changes after a drag. Live appearance preview uses matching rounded styling.

Global visual and authoring preferences are directly available within Settings; chart/song/session configuration remains in its existing scope. Sync helper returns to the same category. Refresh synchronizes values without rounding or firing preference updates. Focused settings/persistence/scoping/compact-layout checks and existing settings-scope/navigation motion regressions PASS; all four category screenshots visually checked. See docs/SETTINGS_UI.md.


## Larger general UI controls

Enlarged lobby mode tiles/gear, song-browser navigation/tabs/rows/favorites/auto/settings/difficulty/section/Play controls, chart-library import/navigation/tabs/rows/versions/New/Manage/actions and confirmation buttons, results navigation/timing controls, audio sync helper actions and note-guide Back. Gameplay pause now has larger actions and a larger pause target. Retained Settings' large controls. Layout spacing and text sizes are adjusted with the targets. Version lists continue to scroll when more options are present.

Chart recorder/editor toolbar buttons and compact text remain unchanged. Recorder pause target/modal/actions also retain their previous geometry; gameplay pause sizes are applied separately. Button-size-scope test, recorder workflow, song browser, chart library, results and lobby navigation/motion checks PASS. Desktop/compact screenshots checked.


## Live page backgrounds and UI motion

The song browser, chart library, Settings and results share an animated atmosphere with layered drifting stars, moving haze and traveling light packets. Local background clocks stop while hidden; shaders respect screen fades. The lobby retains its video background plus a subtle live particle/light overlay. Audio sync and the loading-card backdrop add gentle image drift and atmospheric motion.

Rounded button focus/hover/press lighting now eases continuously; rows fade in with a short stagger and smooth hover lighting; favorites and Auto toggle states animate. Settings transitions and lobby icon/equalizer/rim motion remain active. No idle caption scaling or logo pulse is added.

Removed highway entrance zoom. Camera FOV, angle and rest position remain fixed throughout loading/entrance; miss shake is cleared during the intro. The loading card and HUD can still fade over the stationary highway.

Focused tests verify rendered background-frame changes, visible/hidden clocks, button/toggle interpolation and invariant highway camera projection through the intro. Navigation, Settings persistence/scope, lobby motion and equal-pad/long-hold regressions PASS.


## Rail-bounded notes/beams and touch-position hits

Added a shared camera-projected rail mask for note faces/walls, flick arrows, hold/slide ribbons and edges, release rings and full-width finger beams. Outer visuals stop at the rails without shifting lane centers, reducing interior note/beam widths or changing full-pad input. Raised note faces use their projected ground position to prevent spill at shallow and steep angles. Hit flash artwork keeps its original style and remains independent of note clipping.

Manual hit effects now anchor to each pointer's actual ground-projected touch position, not its rounded lane. Hold/slide effects follow that finger, including reattached pointers; the secondary slide glow uses the same anchor. Flick effects use the swipe position at judgment. Auto Play falls back to the note position on the judgment line.

GPU pixel checks at 18°, 29° and 44° with both note shapes, 125% note size and 150% shared trail width show no note/beam pixels beyond the rail silhouette (with antialias tolerance). Independent two-finger anchors, held-finger movement, slide/flick positions and Auto fallback checks PASS. Note sizing, results/scoring, equal-pad/long-hold and practice/timing regressions PASS.
