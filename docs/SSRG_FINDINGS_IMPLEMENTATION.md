# Remaining APK findings applied

Scope: ordinary shared SSRG rendering and imported SSRG playable input. Special event/item note effects are excluded. Source evidence is static APK/ARM64/Unity data, not execution of the reference game. This supersedes older notes that describe approximate hit size, constant note artwork, and time-only imported draw order.

## Applied

- Blue tap and yellow sustain sprites now use the exact twelve-slot, six-image beat-synchronized ordinary sequences. Phase follows the chart beat offset and the frozen visual clock on pause.
- Connectors use the native projected endpoint normal, 116-unit logical note height, .4/.5 width factors, extra noteScale*1.3 in the horizontal component, and fixed 0/1/2-source-pixel horizontal expansions. The three source chips l1/l2/l3 are drawn as overlapping quads in original order with .2 alpha each. Hold segments connect actual chart checkpoints instead of artificial 96Hz subdivisions. The continuation/end puck remains 132x72 rather than the logical 212x116 used for connector width.
- Missed sustain nodes multiply by source (.2,.2,.2,.25), with no invented grayscale fade. Already successful start nodes remain white. Missed geometry can pass the hit line until it leaves the view.
- Hit flash geometry uses the centered 310x186 source sprite under its (2,2) parent scale, giving 620x372 source units. Existing confirmed 33FPS animation, pause freeze, source alpha-additive blending and .1-second sustain retriggers remain. Independent dense-hit instances remain as requested by the user.
- Imported raw record order is retained for head/checkpoint/end sprite and individual connector-segment sorting, including simultaneous notes and crossing chains. Old imported charts retain the time fallback; a normal folder rescan recognizes parser v3. Saved source times/lanes are not changed.
- Beams have thirteen stable source channels and retain their channel while fading linearly for 100ms after release. A new finger does not move another channel's fading beam. Pause freezes their state; countdown and recorder transitions hide/reset them.
- Ordinary judgment/combo pop uses the original unweighted Hermite curves. Original PERFECT, GOOD and MISS sprites replace text fallbacks; S-PERFECT continues to use its original artwork. No red miss bar is introduced.
- The judgment bar uses the exact Main_black BG3 sprite (including its slanted ends/alpha mask) and native fixed gold tier color #FFDC41 with149/255 alpha. It draws above the rail road shading and below beams/guides/notes, matching source z ordering. The gray synthetic strip is removed. Card UI and special effects are not enabled to obtain this color.
- Imported SSRG input uses source 4/7/13-key rectangles and outer side rectangles, not the wide drawn puck hitbox. Head/end timing uses packaged .3-second windows and rate thresholds .7/.3/.00001, mapping to internal PERFECT/GREAT/GOOD; middle checkpoint windows are .2 seconds. Slide heads and ends now score separately. Early release allowance is .225 seconds and tail timing is measured at the tail, not copied from the head. Hold/slide end checks use the matching channel.
- SSRG speed control exposes the original 1..10 value and maps it to value/3. Existing normalized saved speeds migrate in memory without changing their travel time (within the original supported range); normal chart/recorder speed settings remain separate.

## Bounds and remaining unknowns

The earlier user-facing list included research candidates as well as recovered behavior. It was not evidence that every subsystem had been completely reconstructed.

| Candidate | Current boundary |
| --- | --- |
| Connector width/color/joins | Native three-quad construction applied. Imports with retained record metadata sort each segment separately; older imports use their existing chain/time fallback until rescanned. |
| Note glow | Ordinary source sequence and beat phase applied. No special event frames enabled. |
| Hit dimensions/pivots | Source sprite and inherited parent scale applied. |
| Simultaneous notes | Relative raw import record order applied. Source runtime ID creation across excluded special events is not claimed. |
| Missed holds | Confirmed tint and passing geometry applied. Full recovery/regrab state machine remains unproven; existing cancellation behavior remains. |
| Hold/slide tracking | Source channel rectangles, middle/end windows applied. Native autoaim expansion and Lost/UseMoved transitions remain incompletely traced. |
| Judgment windows | Packaged defaults applied only to imported SSRG. Original ConfigControl IDs15005..15010 can override these online; those server values are unavailable. |
| Speed | Original control mapping applied. Active speed in the supplied reference recording remains unknown. |
| Screen scaling / stage placement | Existing proportional, centered 640-unit canvas and tested 4/7/13 geometry preserved. Native UIRoot height is known, but device ScreenReducer resolution selection is not; using raw screen pixels would regress the video match. |
| Beam release | Confirmed linear clip at native speed10 applied (100ms). |
| Background effects | Existing lasers retained. Original particle/rave lifecycle and beat-dependent animation speed remain unproven; not replaced with guesses. |
| Judgment/combo | Confirmed artwork and pop curves applied. Full live clip duration remains unresolved, so current word fade and persistent combo lifetime remain. |
| Entrance/pause | Animation clocks freeze; hidden notes during user-requested countdown remain. Original resume audio/coroutine and device gesture behavior are not replaced from incomplete evidence. |
| Performance | Shared frame materials, retained pools and loading batches remain; stable thirteen-channel beams add only three meshes. Desktop display reports32Hz; no claim of phone frame rate or hitch-free performance. |

## Validation

New integration tests exercise actual pointer input, source grade boundaries, adjacent-channel rejection, separate slide start/end scores, stable released beams and pause, immediate missed-tail tint, inherited hit dimensions, import order and speed migration. Native-data unit checks cover source curves, frame sequences, touch rectangles and imports. Existing GPU overlap/alignment, shared gameplay, movement and restored recorder checks are retained. The supplied 239-note/13-key chart and Ogg audio complete a full desktop autoplay run with no backward visual-clock steps. This is not human phone testing.

Supporting source locations, hashes and limitations are in SSRG_INPUT_RULES_EVIDENCE.md, SSRG_NOTE_ANIMATION_FINDINGS.md, SSRG_SOURCE_STAGE_ANIMATIONS.md and SSRG_EFFECT_TIMING_LAYERS.md. Local uncommitted evidence includes assets/hit-geometry.json under .tools/ssrg-apk-analysis.
