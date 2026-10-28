# SSRG connector chain semantics re-audit

Re-audit date:2026-10-28. This report examines the retained supplied arm64 `libil2cpp.so` (SHA256 `e4ee507e90cc435d0401a4085881a3c322ca8bb306b47b92a389f58762fc053b`) and IL2CPP metadata/dump (metadata SHA256 `39ae1f606d8572219a263f2934c0e8f688de3e2128f7b8513f600552496fccfe`). Evidence is static native control flow decoded with retained Capstone/ELF tooling. The original game was not executed. Gameplay source was not edited for this audit. Caller-side timing gates are audited separately in SSRG_CONNECTOR_CALL_GATES_AUDIT.md; do not infer the earliest actual judgment solely from this callee.

## Material corrections to earlier reports

1. **`IsLongMiddle` includes the terminal continuation.** Its getter is `NoteType == Long(2)`; it does not exclude `IsLongEnd`. Therefore the normal previous-node rate/grade inheritance also applies to a terminal continuation. Earlier language saying an actively touched end necessarily receives an independent timing grade was incomplete.
2. **`IsLongSlide` is a same-tick-link flag, not a synonym for a visually moving SYNK slide.** `MarkSetSlide` marks both adjacent linked nodes only when their `Tick` values are equal. A timed diagonal/moving chain is not enough to infer this flag.
3. **Lost4 is accepted on one normal Long-state path.** For a nonmissed chain with `IsReleased == false`, unsigned `(trackState - 1) <= 3` accepts1,2,3,4. Earlier summaries limiting this path to1..3 incorrectly omitted Lost.
4. **An End-state branch's temporary rate0.1 does not prove a final GOOD.** Final previous-node grade inheritance can replace that grade. The explicit forced-Good history path has a separate flag and must be distinguished.
5. **The generic initial-release path is not fully established.** `!IsReleased` rejects End5 at the callee's state gate; the branch accepting terminal End is conditional on `IsReleased` already being true. No independent initial setter was established in this bounded audit. Do not claim every ordinary first lift is accepted/forced Good from this branch alone.

## Classification and links

Metadata `Note.NOTE_TYPE`: Default0, LongStart1, Long2; None-1. `Note.JUDGEMENT`: Miss0, Good1, Perfect2, SuperPerfect3, Max4 (unjudged sentinel).

| Native location | Exact observation |
| --- | --- |
| `Note.get_IsLongStart`0x28E1A34 | Tests `NoteType == 1`. |
| `Note.get_IsLongMiddle`0x28E1D34..D40 | Tests `NoteType == 2`, including the last continuation. |
| `Note.get_IsLongEnd`0x28E1D44..D60 | `IsLongNote && LongNext == null`. It is independent of the Middle getter. |
| `Note.get_IsJudged`0x28E1D24..D30 | `Judge != Max4`. |
| `LongNoteInfo.Create`0x28E17A0..17E0 and `CollectSlide`0x28E1978..19C4 | Links individual Note records with LongPrev/LongNext, updates Last and assigns the shared LongInfo. Create also groups eligible same-tick candidates; it is richer than simply one open record list per property. |
| `LongNoteInfo.MarkSetSlide`0x28E1A44..1A84 | Traverses Start->LongNext; if adjacent nodes' Tick fields(+0x70) are equal, writes1 to each IsLongSlide(+0x121). No lane-difference test occurs. |
| `Note.OnJudgement`0x28E2100..213C | Stores node JudgeRate/JudgeTick/Judge, and for a successful long node assigns `LongInfo.Current = node`. |

The judged objects are linked Note records with their own channel and time. The investigated judgment handler reads the node's ChannelId/TrackInfo and rate; it does not evaluate perpendicular distance along the rendered ribbon. `RenderLongLine` draws a segment between linked notes separately. This supports node-based connector judgment rather than scoring every point on a continuous graphic. It is not a claim that every unrelated source input helper was exhaustively ruled out.

## Long-state eligibility inside UpdateNoteJudgement

At0x258A828..A848, the handler looks up TrackInfo by the node's ChannelId. A channel-consumed flag is checked at0x258A89C..A8BC; a successful judgment marks it at0x258AAC0..AAE8. The channel's Touch is captured at0x258A8C0 and stored into LongInfo.Touch for long judgments at0x258AAA4..AABC.

- LongStart1: states1/2 (UseBegan/UseMoved) enter eligibility (`0x258A874..A884`).
- Default0: state1 (UseBegan) enters (`0x258A88C..A898`).
- Long2: if LongInfo.IsMiss is true, the nonnull-track branch returns false (`0x258A85C..A870`).
- Long2, no current miss, IsReleased false: `0x258A988..A998` accepts states1..4 inclusive. With IsLongSlide true, `0x258A99C..A9A0` proceeds directly to rate evaluation. With IsLongSlide false there are additional IsJudged/time branches; caller timing gates also matter.
- Long2, no current miss, IsReleased true: `0x258A8FC..A960` accepts states1..3, or End5 only for an IsLongEnd node within0.75*frontLongEnd. Packaged frontLongEnd0.3 implies225ms, but remote ConfigControl can override it.

No unconditional 'finger left a channel => whole chain immediately MISS' follows from these branches. Lost can remain eligible in the unreleased Long path. A whole-chain actual Miss is distinct from a transient track Lost.

## Rate and grade inheritance, including terminal continuations

Rate eligibility initially uses GetRateLong for Long2 nodes and GetRateLongEnd for an IsLongEnd node (`0x258A8C4..A984`). Positive rates enter long-history processing (`0x258A9FC..AA18`).

For a positive non-End long judgment:

- If IsMissEvenOnce or IsReleasedEvenOnce is true, `0x258AA48..AA84` substitutes rate0.1, clears current IsReleased, sets a force-Good flag (`w24=1`) and final grade Good1.
- Otherwise `0x258AC28..AC40` copies LongPrev.JudgeRate when LongPrev exists (or keeps current rate when it does not), then returns to eligibility/timing grading.
- Later `0x258AAF0..AB18` checks `get_IsLongMiddle` (Long2). With LongPrev present, no forced-penalty flag and a judged predecessor, it copies LongPrev.Judge directly into the final grade. Missing/unjudged predecessor or forced penalty falls back to Good at0x258AB1C..AB2C.

Because terminal continuations are Long2, they also execute this final override. The end-rate function establishes eligibility but does not by itself establish an independent final grade. Rate and grade must be reported separately.

## Conditional End-state behavior

At0x258AA18..AA38, an admitted End5 long judgment sets IsReleased and IsReleasedEvenOnce (two-byte0x0101 store atLongInfo+0x2E) and substitutes the float atVA0xF05470, decoded as0.10000000149. It then calls CheckJudgementByTiming through0x258AA88, **with force flag w24=0**. Thus the initial timing grade is Good under packaged thresholds, but the final Long2 inheritance block can replace it with a successfully judged predecessor's grade. It is incorrect to equate this temporary rate with an unconditional final Good.

Subsequent positive active judgments with the release-history flag use the separate forced-Good path. This establishes a conditional history penalty, not that every generic lift/re-grab sets it.

Initialization boundary: LongInfo's constructor is Object.ctor; Clear zeroes0x28..2F and its Current/Touch references. The retained code explicitly sets release flags in the End branch and clears current IsReleased in the active/history branch. A bounded native scan of direct STRB/STRH stores tooffset0x2E across the il2cpp section found only those IngameView writes among game methods; scans of direct wide stores covering the byte in IngameView/Note/LongInfo did not establish another initializer. Rebasing/indirect writers, external feature paths and live reachability are not exhaustively excluded. UpdateViewNotes0x2588590 only sets stack/local flags, while its0x25885E0..87E0 loop handles linked-node end/render/fill behavior rather than visibly setting IsReleased.

## Actual chain miss

`Note.OnJudgement`0x28E2164..2230 sets IsMiss/IsMissEvenOnce and clears LongInfo.Touch on the first Miss. It walks Start->LongNext and sets previously unjudged Max4 nodes to Miss0. Previously earned judgments are not re-counted by this fan-out. UpdateViewNotes0x2588174..818C can clear transient IsMiss after a positive judgment, but this does not undo already stored Miss grades or the history flag.

## Remaining gaps

- Source runtime initial-release reachability/setter remains unresolved; distinguish the observed conditional branch from a normal input promise.
- Caller gates and exact earliest execution belong to the independent caller audit.
- Online timing overrides and original live finger behavior are not available.
- Same-tick node grouping/order must be retained before claiming exact connector chain parity; a moving path flag and strictly increasing offsets alone do not encode source IsLongSlide semantics.
