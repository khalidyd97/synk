# SSRG input defaults recovered from the supplied APK

This is offline static evidence from the supplied arm64 libil2cpp.so (SHA256 e4ee507e90cc435d0401a4085881a3c322ca8bb306b47b92a389f58762fc053b), IL2CPP metadata (SHA256 39ae1f606d8572219a263f2934c0e8f688de3e2128f7b8513f600552496fccfe), and packaged level10. Names/layouts come from the metadata dump; executable calculations come from ARM64 instructions decoded with Capstone. REA native analysis was unavailable; retained artifact identity and local static evidence were reused. No live reference-game touch test was performed.

## Confirmed calculations and packaged defaults

- `IngameView.GetRate` 0x2583090 and 0x25830B4: rate = 1 - abs(currentSec-noteSec)/selectedWindow. Front window is selected before the note, rear window after it. GetRateLong 0x2583140 and GetRateLongEnd 0x25831CC use their corresponding static windows.
- Metadata constants: front/rear head and end windows .3 seconds; middle windows .2 seconds. Rate thresholds Good=.00001, Perfect=.3, SuperPerfect=.7. `CheckJudgementByTiming` 0x2583258 searches thresholds in descending order and returns the first passing index. Values below all thresholds return Max (4), not a playable grade.
- Default head/end thresholds therefore correspond to S·PERFECT up to 90ms, PERFECT up to 210ms, GOOD below approximately 300ms. Middle-node thresholds are 60/140/200ms. Internal SYNK PERFECT/GREAT/GOOD map to source SuperPerfect/Perfect/Good; existing result storage uses SYNK names.
- `ApplyJudgeTimming` 0x2585990 calls ConfigControl.GetSafe: IDs 15005,15006,15007 replace head/middle/end windows; IDs15008,15009,15010 replace grade thresholds. These defaults are not a claim about the current online game's server settings.
- `UpdateNoteJudgement` 0x258A918..0x258A960 accepts an End-state long end when noteSec-currentSec <= .75*frontLongEnd. Packaged default early-release allowance is therefore .225s. This branch alone does not recover all release/regrab behavior.
- `noteSpeedMultiplier` divides UI noteSpeed by3. SYNK stores a normalized multiplier already; the equivalent source label is SYNK multiplier*3. No new travel-curve change is needed.

## Touch rectangles, distinct from note artwork

Level10 contains 30 BoxCollider2D components (IDs2318..2347): 4/7/13 main rectangles plus two side rectangles per mode. Parents from collider through touchArea/track/objects/MainPanel have identity local scale; UIRoot performs screen scaling.

Main centers use source thirteen-slot channel coordinates x=(channel-6)*62.7139231364, y=-234. Rect offset y=10, height450, so vertical range is [-449,1). Width is251 for4key,125.5 for7key,62.75 for13key. Four-key centers use source channels0,4,8,12; seven-key0,2,4,6,8,10,12; thirteen-key0..12. ContainsTrack 0x2589518 uses inclusive minimum/exclusive maximum rectangle tests.

Side rectangles: 4key x±525,width175;7key x±510,width200;13key x±510,width205. All share the same vertical interval. These bridge the outer touch areas but are not a license to increase every note's hitbox to its sprite width212.

`CheckJudgementByPosition` 0x2583318 compares touch x distance against a constructor default31.800001. However, no call to this helper appears in the investigated UpdateNoteJudgement path, so spatial grade downgrading is not applied from that isolated helper.

`ContainsTrack` inspects an active long note's own touch rect and tracks the same IngameTouch object for autoaim. `UpdateInputParse` 0x2589DB4 assigns UseBegan/UseMoved/Use/Lost/End states when fingers change channels. That confirms sustained movement is stateful, but the full note-specific rect generation, regrab timing, and missed-long recovery rules remain partially traced. No arbitrary grace duration is presented as original behavior.

## Implementation boundary

`scripts/ssrg_input_rules.gd` exposes the confirmed defaults, rate-to-grade mapping, source touch rectangles, end-release allowance, and speed-label conversion. Integrate only when `ssrg_playable_run` is true. Normal SYNK charts and recorder input must keep their settings. Tests cover grade boundaries, symmetric timing rates, mode-specific touch widths, vertical boundaries, outer side rectangles, and UI speed conversion.

Remaining unknowns: online overrides; exact autoaim rect construction for moving long nodes; full regrab/missed-long recovery semantics; dynamic calibration/tempo interaction; resume-lock coroutine details. Existing pause/countdown behavior remains unless further evidence establishes a specific change.
