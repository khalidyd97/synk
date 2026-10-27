# Shared SSRG gameplay reconstruction

Source: `D:\stayc\extract 2`, inspected on 2026-10-27.

## Confirmed by extracted hierarchy and sprite metadata

- `Assets/SceneHierarchyObject/IngameScene.glb` contains a `UI Root (2D)` scaled 1/360.
- Stage top is (0,280); receptor centers are at y=-234, with x positions from -376.28354 to +376.28354, spaced 62.71392 units.
- 4-key charts use positions 0,4,8,12; 7-key charts use 0,2,4,6,8,10,12; 13-key charts use all positions.
- Bottom sprite: 1156 by 130, centered around (5,-250).
- Normal note sprites: 212 by 116. Normal `na1` is blue and `nb1` is yellow; `long/nc1` is the yellow end cap.
- `ingame_3_eff_one` includes eleven A frames and eleven B frames, perfect-judgment artwork and combo digits.

## Implementation

Normal SYNK play and SSRG Playables now share the SSRG renderer, lane-space projection, note art, straight slide connectors, receptor geometry, judgment artwork and hit frame playback. The recorder remains separate. Import identity, chart filtering and lane-count metadata remain separate from the shared renderer. Existing normal charts retain their ten note positions; imported charts retain their original 4/7/13 positions. Slide interpolation is selected on runtime copies rather than modifying saved charts.

The extracted `track/path` holds one `top` point at (0,280) and the thirteen `bottomCen` receptors at y=-234, so every note travels a straight line from a single vanishing point to its lane. Notes were tracked frame by frame in a 1322x590, 30 fps gameplay recording (2026-10-27). That layout maps at 0.931 px per unit around (661,295), placing the vanishing point at y=34.3 and the line at y=513. Along each path, note width stays proportional to progress p (about 149 px times p), as in a perspective projection. Over time, p fits p = (K^u - 1)/(K - 1) with K = 3.3 and a trip of 1.17 s from the top point to the line (RMS 0.015 in p). True constant-speed perspective fits three times worse: notes leave the top point and arrive about 3.3 times faster than they left. The recording's in-game speed setting is unknown, so 1.17 s is used at speed 1.

The perspective camera remains a fitted Godot reconstruction; there is no exported original FOV in the GLB. Notes keep a linear track z, and `ssrg_warp.gdshaderinc` moves note heads, caps, flick arrows (rigidly) and solid trails (per vertex) to the depth at which the camera draws them at that p. Clipping, fading, timing and touch judgement still use the linear z, and the hit timestamp still lands on the line. This is a footage fit, not a recovered source curve. A frames are assigned to taps and B frames to sustains as a reconstruction choice. Dense effects are not forcibly evicted at 24 hits.

## Limits

The extracted Assemblies directory is empty. No original movement implementation, judgment thresholds, scoring formula or animation keyframe timing is present in the inspected files. Camera fitting, travel duration, animation lifetime and input windows are approximations informed by the provided footage, not recovered original constants. The implementation therefore does not establish exact behavioral equivalence with the original game. Existing SYNK scoring and chart semantics are retained where original behavior is unverified; legacy flick charts remain playable.

## Validation

`test_shared_ssrg_gameplay.gd` checks shared activation, ten-lane normal play, unchanged saved charts, visible receptor geometry, extracted hold artwork, dense-hit continuity, both frame sets, pause behavior and recorder/menu isolation. Recorder restoration, imported lane preservation, slide width and reference-motion checks cover the adjacent systems.

## Superseding APK evidence

The later supplied APKs revealed explicit2D sixth-power motion. The footage-fit travel and exponential curve are superseded by the implementation documented in SSRG_APK_NOTE_ANALYSIS.md: position and size use p^6, base duration3.5 seconds at normalized1x, raw visibility cutoff.5, source note maxima212x116 and132x72. The SSRG renderer now uses an orthographic2D canvas and original rail sprite placement; no inverse perspective mapping remains. See the analysis report for the explicit logical-resolution choice and remaining runtime unknowns.
