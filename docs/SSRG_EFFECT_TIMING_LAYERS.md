# SSRG hit timing and draw order

2026-10-27. Static evidence from the user-supplied APK set; original-game execution was not performed.

## Confirmed animation behavior

- Packaged `NoteCoolbomb` (`a940ed1b916017f439f96f074e7cb555`) and `NoteCoolbomb_Star` (`d9103d0b5901fe94bb6528b65806ee60`) animate `UISpriteFrame.Current` linearly from 0 to 11 in 0.3333333433 seconds (slope 33). No extra opacity or scale curves.
- `UISpriteFrame::LateUpdate` at 0x27CCF04 truncates Current: image index floor(33 * elapsed). Each atlas branch has eleven images. The terminal 11 is not an extra image.
- `IngameRenderer::EndRender` at 0x251837C calls `UICache::AnimationAutoHide` at 0x2893FCC: hide when no animation plays or normalized time reaches 1.
- `RenderLongCoolbombTouch` at 0x2517458 suppresses retrigger while the animation is playing with normalized time <= 0.3000000119, then rewinds/replays the default effect. Holds therefore restart the opening burst after approximately 0.1 seconds, rather than looping middle frames.
- `RenderCoolbomb` at 0x251729C uses default A for ordinary taps and first long-note judgments. B is selected for special event/item notes (`Note.IsSpecial`), not holds or perfect judgments. SYNK currently has no corresponding special event system, so ordinary taps, holds and slides all use A; B artwork remains available.
- Effect atlas material resolves to `Unlit/Transparent SrcAlpha One`: SrcAlpha/One additive blending, zWrite=0, two sided, LEqual depth test. Existing effect shader already matches this blend.

## Confirmed layering and adaptation

Serialized scene level10 widget mZ values: rails -1.3611112, touch beams -1.6666667, guides -1.6944445, note batch -4.166667, hit sprites -19.166668. With the scene camera facing positive Z, notes are in front of beams/guides and hit sprites are foremost.

Native `RenderNote` at 0x251687C allocates batch order 20,000,000 - 100 * Note.Id. `RenderLongLine` at 0x2516BC0 allocates 10,000,000 - 100 * Note.Id. `UIBatchSpriteSorter::EndUpdate` at 0x26B77DC sorts ascending using its comparer at 0x26B8184. Thus connectors precede heads, and earlier IDs render later within each category.

SYNK maps this to explicit material priorities: bar -8, rails -7, beams -6, guides -5, connectors -4, heads 0, flashes 6. Earlier chart times sort above later times; smaller connector caps use their checkpoint time. Time ordering is an adaptation because SYNK does not preserve a source Note.Id for every generated connector. Equal-time ties retain the engine's stable object ordering rather than claiming exact source ID parity. GPU readback verifies earlier/later overlapping heads in reverse construction order.

Source repeated taps rewind one channel effect. SYNK deliberately keeps independent overlapping tap effects to honor the user's earlier request for uninterrupted dense-section effects. The recovered one-third-second timing still applies to every instance. SSRG flashes now also clear with other hit effects on chart transitions/palette resets.

Recorder geometry/material behavior remains separate. No judgment windows, scoring, imported chart timings, or note movement curves changed.

## Retained local evidence and validation

Ignored local evidence under `.tools/ssrg-apk-analysis`: animation clip JSON files above in `assets/`, `assets/hit-shader.json`, `assets/layer-evidence.json`, and disassemblies for UISpriteFrame LateUpdate, RenderCoolbomb, RenderLongCoolbombTouch, EndRender, RenderNote, RenderLongLine and UIBatchSpriteSorter comparer/EndUpdate.

`godot_tests/test_ssrg_effect_timing_layers.gd` checks frame boundaries, terminal hide, paused clock, hold retrigger/release, ordinary sustain artwork, dense overlap retention, transition cleanup, layer priorities and actual overlapping-head pixels. Existing render alignment, shared gameplay and recorder checks cover the shared stage and recorder isolation.
