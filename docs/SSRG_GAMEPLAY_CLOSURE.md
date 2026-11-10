# SSRG Gameplay Closure

Last updated: 2026-11-10

This is the living implementation map for applying the recovered Android SSRG gameplay behavior to Synk's shared Godot gameplay. PvP/Music Battle opponent mechanics are intentionally excluded.

## Applied gameplay contract

- Notes are positioned from absolute chart/audio time, so pause, seek, tempo changes, and frame stalls do not accumulate visual drift.
- The recovered 4-, 7-, and 13-lane highway geometry, rails, target line, note families, long-note strips, HUD art, fever layers, effects, and popup art live under `assets/ssrg/imported` and are drawn by the existing SSRG stage.
- Touches use stable ordering, one consumed channel per update, retained physical-owner identity for long chains, and source-compatible lane auto-aim.
- Tap and flick heads use the recovered 300 ms acceptance window, while an untouched ordinary head automatically misses at the inclusive 30 ms late boundary after input processing.
- SSRG touch sync is stored separately from the shared chart/audio offset. It calibrates the gameplay-clock sample attached to press and release events; positive milliseconds compensate late touch delivery, and judgment windows are never widened.
- Holds and slides preserve separate head, middle-node, tail, early-release, ownership, re-entry, and degraded-chain history.
- Held combo cadence uses `seconds_per_beat / 6`, a per-chain fractional accumulator, catch-up after frame stalls, and strict `> 1.0` emission.
- Judgment score, plain score, and pending rave bonus remain floating-point internally. Public values use positive half-up rounding. The per-result rave amount is `rounded total - rounded plain`, not a separately rounded accumulator.
- Miss settles pending rave before life/fever mutation. Difficulty life penalties are 10/20/30 for 4/7/13 lanes; recovery is 1/0.5/0.3334 for accepted Perfect-class judgments, and Good does not recover life.
- Pause retains simulation state, resumes from calibrated audio time, and rebuilds a lost audio handle. Completion resolves remaining notes and tails before settling pending rave and freezing the result snapshot.
- An effect-suppressed seek Miss still records the Miss and resets combo, but does not shake the stage, damage life/fever, or emit gameplay presentation callbacks.
- Normal offline play enters a guarded failure state at exactly zero clamped life. Failure pauses clocks and judgment input and exposes Retry and Song List actions; practice mode is exempt.
- A positive final pending rave is applied before the immutable result snapshot and holds the finish transition for the recovered three-second final-rave interval.
- Results now retain total score, plain score, derived rave bonus, final life, and final fever state in addition to combo and judgment counts.

## Validation ownership

Automated Godot tests cover timing windows, touch routing, multifinger arbitration, flick direction, long-chain ownership and release, 30/60/120 Hz held cadence, scoring, fever/life, pause recovery, rendering alignment, and result flow. Physical iPhone validation is still required for audio-route latency, safe-area/crop composition, 60/120 Hz visual timing, interruption touch continuity, and final device feel.

Samsung SM-A736B smoke validation on 2026-11-10 confirmed installation, process focus, Godot surface creation, first-frame rendering, and the animated SYNK intro without a SYNK/Godot fatal exception or ANR. Automated device control cannot establish human touch feel, speaker/Bluetooth/wired acoustic latency, or finger-held interruption continuity; those remain physical measurement tasks rather than missing gameplay code.

## Update rule

When new runtime evidence changes a rule, update this file, the smallest owning SSRG module, and a deterministic regression test in the same change. Do not infer PvP behavior or change the normal Synk gameplay kernel to satisfy an SSRG-only rule.
