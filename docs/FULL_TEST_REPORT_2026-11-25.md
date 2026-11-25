# Full test report — 25 November 2026

Code tested: branch `codex/ios-build-20261120-glow` at `57e8d85`, then `7f50259` after the fix.
Everything here ran on the Windows PC (Godot 4.7.2, OpenGL compatibility renderer).
**Nothing was tested on a phone**, and no APK or IPA was built for this pass.

## Summary

| | Count |
|---|---|
| Automated test scripts run | 146 (now 147 with the new one) |
| Pass | 100 (now 101) |
| Fail | 46 |
| Failures caused by recent work (SYNK mode and later) | 0 |
| Failures that already failed before SYNK mode was added | 46 |
| Real bugs found | 1, fixed |
| Breaking changes made | none |

## What was tested

1. **Every script in `godot_tests/`** (146). 86 pass without a window. The other 60 were
   re-run with a real window, because many take screenshots and hang without one; 14 more
   pass that way.
2. **Comparison with older code.** All 46 failing tests were run against commit `b8e0d8c`,
   the last one before SYNK mode. With the same saved settings, every one of them fails
   there too, with the same checks.
3. **Smoke tour** in a 1280×720 window: lobby, chart library, chart studio, guide, recorder,
   then a song on autoplay in the SSRG style and in SYNK mode, each with pause, resume and
   exit. The log was checked for script and shader errors. Screens:
   `recordings/SYNK-full-test-screens.png`.

## Bug found and fixed

**SYNK mode: the stage refresh stopped half way on pause, resume and exit** (`7f50259`).

- SYNK mode's backdrop helper is a plain node that cannot be shown or hidden. The loop in
  `scripts/ssrg_highway.gd` `refresh()` that hides the stage's other pieces tried to hide
  it, raised a script error, and skipped the rest of the refresh (the song-photo backdrop
  state).
- It happened on every pause, resume and exit of a SYNK mode song after the first, several
  times per action.
- Fix: skip nodes that have no visibility. New test: `godot_tests/test_synk_mode_pause.gd`
  (fails without the fix, passes with it).
- Visible effect on a phone is unknown; it was found from the error log, not from a
  visual fault.

## Breaking changes

None. The fix changes no saved data, chart format, setting or behaviour that worked before.

## The 46 failing tests (not fixed)

None of these is new. The ones inspected closely are tests that still describe an older
design, not faults in the game. They were left as they are; updating or deleting them
changes what the suite promises, so that is your decision.

**Refer to things that no longer exist** (the test stops with a script error; 18):
`test_ambient_motion`, `test_chart_library_reference`, `test_concept_highways`, `test_core`,
`test_custom_effects`, `test_editor_clipboard`, `test_editor_range`,
`test_floating_text_input`, `test_game`, `test_highway_backdrop_glow`, `test_hit_styles`,
`test_music_recognition_fallback`, `test_prism_highway`, `test_rail_bounds_touch_hits`,
`test_song_browser`, `test_ssrg_screen_motion`, `test_stage_rail_effects`,
`test_music_recognition`.
Examples: the Prism highway, ambient motes and streaks, `update_ambient_particles`,
`create_version` on the chart library.

**Stop at a failed assertion** (4): `test_gameplay_start_lead`, `test_ssrg_album_card`
("Pause card is opaque"), `test_ssrg_audited_connector_rules`, `test_ssrg_touch_feedback`.

**Run to the end with failed checks** (24): `test_chart_settings` (6),
`test_creator_tools` (7), `test_gameplay_colors` (5), `test_practice_timing` (2),
`test_range_transform` (1), `test_recorder_restored` (1), `test_recorder_seek_overview` (1),
`test_reference_results` (2), `test_settings_drilldown_trails` (6),
`test_settings_redesign` (3), `test_shared_ssrg_gameplay` (1), `test_slide_design` (2),
`test_smooth_gameplay` (1), `test_ssrg_import_scroll` (1), `test_ssrg_native_lifecycle` (1),
`test_ssrg_presentation_systems` (1), `test_ssrg_render_alignment` (16),
`test_ssrg_score_hud` (1), `test_sustain_end_caps` (36), `test_synk_long_visuals` (1),
`test_text_slides` (1), `test_tools_scope` (3), `test_vertical_editor` (4–6),
`test_workbench` (5).

Checked by hand and confirmed to be outdated tests:

- `test_range_transform`: expects mirroring across 10 lanes; the game has 13.
- `test_smooth_gameplay`: expects a missed hold to be deleted once off screen; the game now
  keeps prebuilt notes and hides them, on purpose, to avoid stutter.
- `test_ssrg_presentation_systems`, `test_ssrg_score_hud`: expect ordinary play not to use
  the SSRG look; it now does.
- `test_practice_timing`: passes when run on its own with clean settings.

## Problems with the test suite itself

- **Tests share this PC's real game settings and do not clean up.** They write note speed,
  colours, scores, bookmarks and fixture charts into the game's data folder, so results
  depend on run order (`test_practice_timing`, `test_workbench`, `test_vertical_editor` and
  `test_slide_design` gave different counts between runs). The four settings files were
  backed up before the run and restored after it. Fixture charts and songs with made-up
  ids (`1111…`, `2222…`, `3333…`) are in the PC's game data folder; they were not removed.
- **A test that hits a script error never exits.** It hangs until killed, which is why the
  first full run took over three hours.
- **Many tests need a real window.** They wait for a drawn frame and hang when run headless.

## Not covered

- Phones: touch input, performance, stutter, audio latency, the iOS and Android builds.
- The end-of-song results screen through a real song finish (the smoke tour jumped to it).
- Song import, music recognition against the network, chart sharing between devices.
- Settings screens were opened only by their own tests, not by the smoke tour.
