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
