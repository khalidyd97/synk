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

The existing perspective camera is a fitted Godot reconstruction of the original flat sprite projection; there is no exported original FOV in the GLB. Shared travel is calibrated to 1.07 seconds across 60 world units at speed 1, with arrival at the original chart timestamp. Three saved reference frames at 5.0/5.2/5.4 seconds place the same right-hand tap at y=197/260/403 in a 1240x552 frame. Inverse projection into the fitted camera gives z=-25.20/-14.01/-2.77, approximately 56.1 world units per second. This is a footage fit, not a recovered source speed. A frames are assigned to taps and B frames to sustains as a reconstruction choice. Dense effects are not forcibly evicted at 24 hits.

## Limits

The extracted Assemblies directory is empty. No original movement implementation, judgment thresholds, scoring formula or animation keyframe timing is present in the inspected files. Camera fitting, travel duration, animation lifetime and input windows are approximations informed by the provided footage, not recovered original constants. The implementation therefore does not establish exact behavioral equivalence with the original game. Existing SYNK scoring and chart semantics are retained where original behavior is unverified; legacy flick charts remain playable.

## Validation

`test_shared_ssrg_gameplay.gd` checks shared activation, ten-lane normal play, unchanged saved charts, visible receptor geometry, extracted hold artwork, dense-hit continuity, both frame sets, pause behavior and recorder/menu isolation. Recorder restoration, imported lane preservation, slide width and reference-motion checks cover the adjacent systems.
