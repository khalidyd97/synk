# SSRG stage and beam match to the supplied video

2026-10-27. Follow-up to the APK note investigation. Uses six retained frames from the supplied recording, the supplied split APKs, and desktop renders of the actual game. Native/artifact investigation reused the earlier mapped IL2CPP methods and Unity scene objects; no reference game was executed.

## Actual causes of the stage mismatch

The rail image initially copied from the older D:/stayc extraction differs from the image in the newly supplied APK. The older image contains multiple bright bands and a broader rail. It was incorrectly treated as the original rail for this APK. The correct APK atlas crop is Main_Floor_2,720x578 at atlas rectangle(0,1216)-(720,1794). Its broad noisy RGB region has alpha0 and is invisible with normal source-alpha blending.

The native UIDynamicSprite.OnFill(0x27C7CF8) produces a rectangular sprite. UIWidget.OnApplyTransform(0x26B577C) applies the pivot/ordinary UI matrices. IngameRenderer initialization does not reshape the rail. The material ingame_1_object uses Unlit/Transparent Colored with SrcAlpha/OneMinusSrcAlpha, ZWriteOff/CullOff. A camera deformation is not needed to explain the extracted image.

There were also duplicate synthetic floor layers: two old rectangular perspective-road meshes plus an invented triangular floor. They added a blue rectangle outside the road and extra darkness inside it. SSRG now hides the old floor/shadow meshes and relies on the APK rail texture's own black-alpha road shading. Recorder restores its original floor. Custom track tint and highway darkness apply to the road pixels of the source sprite.

## Measured rail comparison

All measurements below use1240x552, matching the retained video frames. Hough fits over six source frames and a fresh Godot render:

| Measurement | Reference video | Corrected renderer |
|---|---:|---:|
| Left rail dx/dy | -1.00558 | -1.00250 |
| Right rail dx/dy | 1.00386 | 1.00354 |
| Rail separation at y485 | 911.713px | 911.343px |
| Convergence y | 31.286px | 30.701px |
| Convergence x | 625.763px | 619.006px |

The previous rail separation was approximately6.9% too wide. The corrected asset is within0.4px (0.04%) in the measured near-line width. A horizontal offset of approximately6.8px remains between clip and centered renderer; its capture/layout source is unverified. The centered native UI geometry is retained. These measurements do not establish complete pixel-perfect parity.

## Source beam geometry, rather than lane-width estimates

Serialized IngameRenderer TouchTracks binds13 laser_00..laser_12 UIPolySprite objects. Source sprite press line_6:

- Apex(0,286).
- Bottom y=-320, width295.
- Bottom channel centres73.75 apart, around x0.
- Judgment cross-section y=-234: width295*520/606 =253.1353. The old13-lane beam was only about60 units.
- Source4x640 white-alpha strip provides the vertical fade. It has no horizontal feather.
- Source cyan tint(0,0.7843137383,1,1).

SSRG now uses those dimensions, source fade texture and normal source-alpha blending in a separate material. The recorder retains its additive beam material. Existing effect intensity/custom color controls remain available. Beam assignment follows4/7/13-key channel selection; normal SYNK's shared renderer retains its10-key mapping.

## Why the judgment rings looked too high

The original guide sprite note_guide01 has centered pivot, dimensions212x116 and logicaly=-234. Its visible outer ellipse is centred around bitmapy66.44 instead of58. At the video scale552/640 this shifts the visible ring down7.28px, to y485.11. That agrees with the reference. The generated replacement ring lacked that artwork padding.

The renderer now uses the APK guide image at the unchanged judgment position. RenderNoteGuide(0x25170A8) also establishes the original fade: projectedq<.3 is hidden; alpha=clamp(2*(min(q,.8)-.3),0,1) through q1; past q1 it hides. The source guide image and this fade replace the generated circle and screen-midpoint heuristic.

The640-unit logical canvas is consistent with these video measurements. UIRoot itself uses a resolution-dependent active height and ScreenReducer can change the game's rendering resolution, so640 is a video-normalized presentation choice rather than an immutable APK setting.

## Delivered source assets

Only the relevant cropped PNGs are included, not APKs, native libraries or analysis utilities:

- rail_original.png SHA25683da24ba234dee88803315d7600884d8c02abaa5622b83f63dc5292f686a4c97
- beam_original.png SHA25609175747a384e9df9b70f96581381982afd9f510b00cbae330874de110e45809
- guide_original.png SHA256c19cf5ba4324f120e84446ced0421089e4c61c067838c7e366f6502ad07c6bbd

Local evidence includes assets/rail-shader.json, beam-components.json and note-guide-01.png under .tools/ssrg-apk-analysis; video fit data .tools/ssrg-correct-asset-measure.json and diagnostic overlay .tools/ssrg-apk-rail-corrected-geometry-compare.png.

## Validation

GPU render-bounds, early-note visibility,4/7/13 beam placement/width/apex, outer-edge bounds, held clipping, pause/countdown and recorder restoration tests pass. Original movement/timing tests and shared-renderer checks pass. The supplied239-note song was re-imported in the isolated signed-in desktop profile and exercised with two wide beams in playback. No phone installation/launch performed; APK build/signature and connection status are reported separately.
