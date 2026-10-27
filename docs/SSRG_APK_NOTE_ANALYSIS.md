# SSRG note movement: supplied APK evidence

Analysis date: 2026-10-27. Scope: offline inspection of the three operator-supplied APKs. No target app executed or modified; no gameplay implementation changes made.

## Main conclusion

The packaged game uses an orthographic 2D Unity camera and explicit perspective-like position/size math. SYNK's current 3D perspective plus calibrated constant world speed is an approximation, and does not implement the recovered curve. The earlier footage-fit travel value of 1.07 seconds is not an original game constant.

## Identity and tools

- base.apk SHA256: 3c83b6f6d896911379189f646cfc2d24550be9508915ee374300779528bda99b
- Native member: split_config.arm64_v8a.apk/lib/arm64-v8a/libil2cpp.so, SHA256 e4ee507e90cc435d0401a4085881a3c322ca8bb306b47b92a389f58762fc053b
- Metadata member: split_base_assets.apk/assets/bin/Data/Managed/Metadata/global-metadata.dat, SHA256 39ae1f606d8572219a263f2934c0e8f688de3e2128f7b8513f600552496fccfe; IL2CPP metadata version31.
- REA opened and inventoried base.apk: Evidence ev_6b7caca9a4013cdbcd38cc075261e609a93810d49a8bcc344b5a958b5797bad0; no integrity contradictions in that inventory. This inventory alone establishes no gameplay behavior.
- Native deep provider unavailable on this configured host. Supplementary static analysis used Il2CppDumper6.7.46 to map method identities/field offsets, Capstone5.0.9 and pyelftools0.33 for ARM64 instructions/import resolution, and UnityPy for serialized scene objects. Metadata dump method bodies are empty stubs, not decompiled game source. Conclusions below use actual native instructions and serialized fields.

## Recovered formula (ordinary single-tempo path)

Let D be ViewDuration in chart ticks. UpdateViewNotes adds D to the current fractional tick before calling UpdateNotePosition. The latter computes:

```
p = (current_tick + D - note.Tick) / D
q = pow(p, 6.0)
position = TopPos + (lane_bottom_center - TopPos) * q
size = NoteScaleMaximum.xy * noteScale * q
```

At the note timestamp p=1 and q=1. The same calculation is performed separately with TickCali for calibrated touch position; the visual and input positions are intentionally distinct. Multi-tempo charts take additional tempo-conversion branches, so the simple tick equation is not a complete description of those branches.

Proof anchors in libil2cpp.so (virtual addresses):

- IngameRenderer.UpdateNotePosition 0x2516340; ordinary progress at0x251649c..0x25164ac and0x25166bc; stores Pos01 at Note+0xac.
- Calls ToAcceleration at0x25166e4, stores PosAccel01 at Note+0xb0.
- Perspective2dSettings.ToAcceleration 0x251f188 loads Acceleration at+0x34, then branches to0x53d1110. ELF .rela.plt resolves this entry to **powf**, not a camera operation.
- Perspective2dSettings.SampleTopToBottomCen 0x251f22c multiplies TopToBottomCen[channel] by q and adds TopPos.
- Note size at0x251673c..0x2516754 multiplies q * renderer.noteScale * NoteScaleMaximum. Long starts retain full size; subsequent long nodes use LongNoteScaleMaximum at0x251677c..0x25167a4.

Examples of position/size fraction: p=.50 gives1.5625%; p=.75 gives17.7979%; p=.90 gives53.1441%; p=1 gives100%. These are mathematically derived samples, not measured video timings.

## Exact packaged scene values

Unity level10 IngameScene:

- Camera pathID2317: orthographic=true, size1, full viewport, position(0,0,0), identity rotation. Serialized FOV60 is inactive in this orthographic mode.
- UI Root scale1/360. Note hierarchy depth z=-1500 is layering, not falling travel depth.
- Perspective2dSettings pathID2714 on path: Top280, Bottom-234, Degree49.5, Count14 boundaries/CenCount13 lane centers, Acceleration6, IsDivide=true.
- TopPos(0,280); bottom lane centers x=-376.28354..376.28354, step62.71392, y=-234. Boundaries span +/-407.64050.
- IngameRenderer pathID2723 points to settings2714. NoteScaleMaximum(212,116,1); LongNoteScaleMaximum(132,72,1); NoteCutOut=.5; LineCutOut=.5.
- RenderNote at0x25168dc compares NoteCutOut against raw Pos01, and skips drawing below the cutoff. This is not a growing ring or a 3D near-plane rule.

Serialized settings decoded with exact end-of-payload consumption. Full data and per-object bytes are retained locally under .tools/ssrg-apk-analysis/assets/decoded-note-settings.json and render-components.json.

## Speed is a separate calculation

- IngameView.get_noteSpeedMultiplier at0x2582e10 returns noteSpeed/3.
- get_ActualSpeed at0x2582e20 returns Speed*(noteSpeed/3).
- ApplyNoteSpeed at0x258a3a8 clamps the UI value to1..10 and recomputes ViewDuration; SetNoteSpeed at0x2586d4c computes an integer duration from basicTime and a timing-rate field divided by ActualSpeed.
- Constructor at0x258dde4 initializes basicTime to float3.5. Loading code also exposes DEFAULT_NOTE_SHOW_TIME=3.5. Runtime configuration may override defaults; this offline inspection does not establish the speed selected in the reference video.

## Implication for SYNK

Implement the recovered sixth-power position and sprite-scale curve together, using the original lane top/bottom coordinates and hit timestamp. Do not just increase world speed or change the camera lens again. Preserve separate timing calibration and tempo handling. Native code establishes the formula; matching the recording still requires knowing its selected note speed and any runtime configuration.

## Coverage and remaining gaps

Answered: 2D versus3D mechanism, position acceleration, sprite scale coupling, exact packaged note/stage geometry, cutoff, speed multiplier and default base time.
Partially answered: full multi-tempo conversion and active runtime speed/configuration. No live-game validation performed. Hold line topology, hit-effect scheduling and judgment windows were not the focus of this pass and are not claimed recovered here.

Local supporting artifacts: dump/dump.cs (names and layouts only), UpdateNotePosition.asm, Perspective2dSettings method assembly, IngameView speed/update assembly, identity.json, and assets/FINDINGS.md under .tools/ssrg-apk-analysis. These extracted third-party binary artifacts are not committed to SYNK.

## Implementation applied

SYNK now uses a direct orthographic2D canvas for shared SSRG gameplay. The original source coordinates map to world X/Z with z=-(UI_y+234)*UNIT. Position is (lane_x*q, Top+(Bottom-Top)*q), sprite size is source_size*q, q=p^6. No camera perspective or inverse depth approximation remains in the SSRG path. The original720x578 Main_Floor_2 rail sprite is placed with its BottomRight pivot at(0,-320) and mirrored on the right; the1156x130 judgment backdrop is at(-5,-250). Normal note maxima are212x116 and subsequent sustain nodes132x72. RenderLongLine at0x2516bc0 computes a perpendicular normal after projecting its endpoints and uses note height * .4 * .5 * noteScale *1.3 as half-width; constants .4 and1.3 are read at0xf054fc and0xf05490. The connector shader now applies that projected-normal construction and width rather than the prior thin world-space approximation. Raw-progress cutoff is.5 and default base duration3.5 seconds at normalized1x. Hit flashes move toward the orthographic camera vertically, preserving lane/line position; receptor reveal uses the same projected progress. Recorder keeps its perspective camera and timing.

The render canvas currently uses640 logical vertical units to match the supplied footage. Native UIRoot is automatic and clamps the game's render-resolution height to320..2048 (get_activeHeight0x26ADA98; Update0x26AE0E8 uses2/height). ScreenReducer can change that resolution. The selected runtime resolution and speed in the supplied recording are not established, so a claim of complete pixel-perfect/runtime parity would be unsupported. The640 logical-unit mapping is an explicit presentation choice, not a recovered immutable game constant.

Validation: direct orthographic position/size against independent sixth-power samples; speed and hit-plane checks; shared gameplay and recorder isolation; constant-width slide connector tests;4/7/13 import lane preservation; desktop rendering with shader compilation. Android export is built separately for user testing. No live reference-game comparison performed in this implementation pass. Judgment rules, audio clock semantics, full tempo handling and hit animation timing are not claimed exact by these renderer changes.
