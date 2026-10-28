# SSRG sustained touch and recovery

> Correction: the original held tail normally inherits the preceding rate and grade, transient Lost may judge, and provisional End rate.1 does not establish an unconditional final GOOD. See SSRG_CONNECTOR_JUDGMENT_REAUDIT.md; the historical interpretation below is superseded on those points.

Source identity: supplied arm64 `libil2cpp.so`, SHA256 `e4ee507e90cc435d0401a4085881a3c322ca8bb306b47b92a389f58762fc053b`; IL2CPP metadata SHA256 `39ae1f606d8572219a263f2934c0e8f688de3e2128f7b8513f600552496fccfe`. This follows the REA workflow using retained artifact evidence and direct Capstone ARM64 decoding because the native provider was unavailable. Observations below are static control flow, not a live original-game touch test.

## Recovered behavior

`IngameView.UpdateInputParse` at0x2589DB4 tracks UseBegan1, UseMoved2, Use3, Lost4, End5. Finger release sets End and clears that track's touch reference. Moving to a new channel sets the previous channel Lost. Neither path calls OnMiss or sets LongInfo.IsMiss.

`UpdateNoteJudgement` at0x258A7D4 checks each unjudged long node independently. With an unmissed/unreleased long chain, track states1..3 can judge a middle/end node. An End state can judge only the terminal node, and only when endSec-currentSec <=.75*frontLongEnd (default225ms). Idle/Lost/End on a middle merely produce no judgment. `UpdateViewNotes` uses the node's own rear deadline to call OnMiss: middle default200ms, terminal default300ms. A departed finger can therefore be replaced before that next node deadline; no fixed-duration gap timer was recovered or added. Lane entry is stateful, allowing a new finger's UseBegan to satisfy a future node. Original autoaim prefers the stored chain touch for moving nodes; no claim is made that every new-finger aim situation is identical.

`Note.OnJudgement`0x28E2164 sets LongInfo.IsMiss and IsMissEvenOnce, clears its Touch, and walks Start -> LongNext marking every still-unjudged linked node MISS. Therefore actual missed nodes terminate the remaining chain. Recovery after an already-recorded chain miss is not supported by this evidence. A previously scored head must not be counted again.

`UpdateViewNotes`0x2588174..8190 clears the transient IsMiss flag after a positive node judgment, while the history flag remains. This does not undo grades already fanned out by an earlier miss.

## Grade inheritance and release

`UpdateNoteJudgement`0x258AAF0..AB18 gives a successful middle node the preceding already-judged node's grade. An absent/unjudged predecessor instead forces Good. It does not independently regrade every middle according to its timing error. `0x258AA28..AA84` sets release flags and forces Good for an End-state terminal hit. Thus an early lift accepted within225ms is not automatically promoted to the head's grade. An actively touched end is timed normally.

## SYNK integration

`scripts/ssrg_sustain_rules.gd` expresses the recovered node deadline, recoverability, touch-state eligibility, early end release, and middle-grade inheritance. Gate these rules on imported `ssrg_playable_run`; preserve normal SYNK and recorder rules. On finger loss, detach the pointer and keep the started chain active until the next pending checkpoint/end deadline; reattach a valid lane finger before that deadline. Stop held hit-effects while detached. If the deadline passes, use the existing whole-chain miss path exactly once. On an accepted release end, supply Good to grading. Maintain an earned previous-node grade for middle inheritance.

Tests cover departure/regrab before and after each node deadline, early terminal release, recovery prohibition after actual miss, and middle/release grade behavior. Remaining differences include full moving TouchRect2d autoaim selection and source per-frame touch arbitration when multiple fingers compete for one lane.
