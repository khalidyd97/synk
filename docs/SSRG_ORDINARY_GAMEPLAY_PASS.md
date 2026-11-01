# Ordinary SSRG gameplay and new loading screen

Scope: ordinary imported SSRG charts; special-note mechanics were not extended.
Regular SYNK OG retains its timing and scoring. The new loading screen is shared.

## Evidence and implementation

REA reopened the supplied ARM64 ELF and verified SHA256
`e4ee507e90cc435d0401a4085881a3c322ca8bb306b47b92a389f58762fc053b`.
Native decompilation returned `provider_unavailable` on this Windows host.
Analysis continued with retained metadata and direct Capstone/ELF decoding;
the original game was not run. The REA target was closed afterward.

- **Life/rave:** `IngameView.Reset` 0x2586F8C..0x2586F94 initializes life
  to its maximum, not 50%. Static initializer 0x258E024..0x258E02C copies
  constants from 0xF07350/360, 0xF079E0 and 0xF06EE0. Maximum life is 100;
  easy/normal/hard penalties are 10/20/30 and recovery 1/.5/.3334000111.
  GOOD has zero life recovery; ordinary PERFECT and S.PERFECT have rate 1.
  `CalcLifeAndFeverState` 0x2584070..0x25840E8 recovers life and enters state 1
  at full life. Existing source thresholds, entry budgets and level transitions
  now operate independently of SYNK's energy meter. Offline no-fail remains.
- **Score:** `ScoreData.CalcNoteScore` 0x251F760..0x251F7DC multiplies
  `(CardBalanceValue + CurrentCardPointValue) * NoteBalanceValue / NoteCount`.
  Packaged balances are 3 and 10000; static difficulty multipliers are
  .8000000119/.8999999762/1. `CalcJudgeScore` uses the grade rate and difficulty;
  packaged grade defaults are MISS/GOOD/PERFECT/S.PERFECT = 0/.5/1/2.
  `CalcRaveScore` 0x251F8C4..0x251F8D0 adds the rave rate to the grade rate,
  rather than multiplying the judgment score by a combo multiplier. Ordinary
  points accumulate as doubles; rave bonus is banked and settled on interruption
  or song completion. Current local judgment-node count supplies NoteCount.
  A CUSTOM chart has neutral card points (0); optional numeric `card_points`
  in presentation metadata supplies an explicit source-style point value.
  Tier letters never invent card stats. New best records use `ssrg_best_v2`;
  old records are retained under their original keys.
- **Held ticks:** `SetNoteSpeed` 0x2586D80..0x2586DA4 sets ComboDivision to
  seconds-per-beat / 6. `UpdateLongTouch` 0x258AD30..0x258AD74 accumulates
  fractional duration and emits integer counts when credit is strictly > 1.
  Its caller 0x2587D34..0x2587D80 adds score and combo. SYNK now gives ordinary
  sustains these ticks without creating extra judgment grades or accuracy events.
  Physical ownership remains mandatory in manual play. Each elapsed tick scores
  independently, making 30/60/120 FPS agree; native batches can add score once
  while adding multiple combo ticks after a slow frame, an intentional difference.
- **Contact transitions/effects:** retained, identity-validated contacts now stay
  eligible for sustain autoaim after the shared channel becomes Lost. Checkpoint
  and terminal visuals reuse the finger-following sustained effect rather than
  emitting a second trail-position flash. Early tail visual lifetime, original
  hit dimensions and user-requested independent tap overlaps remain.
- **Pause/audio:** `Pause` 0x2588A48..0x2588A58 saves the sequencer's calibrated
  audio position; `Resume` 0x2588BB4..0x2588C5C restores or recreates playback
  there. SYNK captures the heard chart position minus the configured timing
  offset and resumes there after the existing three-second countdown. A lost
  audio handle before or during the interruption no longer restarts the song.
  Visual-clock smoothing is reinitialized. Existing input-event timestamps,
  output-latency compensation and calibration remain, with their regression
  suites checked; Unity/MiniAudio-specific buffer correction is not copied into
  Godot's different audio driver.
- **Loading:** redesigned typography/artwork layout, responsive song details,
  palette-matched orbital lines and a thin stage-preparation progress bar.
  Progress remains bounded by actual note construction. Existing minimum duration,
  warmup and countdown sequencing remain. No new bitmap assets are required.

## Boundaries

This is not proof of identical original online play. Original server overrides
(including ConfigControl 15001..15010 and card balances), card inventory/theme
bonuses, complete native long-note statistics and a synchronized original runtime
recording are unavailable. SYNK's collapsed chain model, owned-release adapter,
same-frame ownership guards and refresh-independent tick scoring remain explicit
adaptations. Imported tempo handling and reported accuracy retain the local chart
model. The user's rave pulse and prolonged finger effects are preserved preferences.

Special-note mechanics are excluded from the new held-tick path. Existing special
art/metadata support is retained without new item behavior or inferred schedules.

## Validation

Sixteen targeted suites passed: new ordinary lifecycle, full integration, input
timestamps, long-slide timing, sustain integration, slide recovery, multiple
fingers, release identity, regular-mode isolation, presentation, particle bounds,
render alignment, score HUD, source curves, audio clock and artwork-aware loading.
The lifecycle suite checks neutral/explicit-card score arithmetic, single bonus
settlement, full initial life, GOOD recovery exclusion, difficulty recovery, fever
budget decay, retained contact identity, checkpoint effect reuse, both lost-audio
resume paths, and identical held-tick score/combo at 30/60/120 FPS.
Loading screenshots at 1440x640, 2400x1080 and 1024x768 were inspected. Desktop
audio fell back to the dummy driver, so these checks do not establish audible
latency or Samsung frame rate. The phone must not be launched by the agent.
