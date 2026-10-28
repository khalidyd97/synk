# SSRG connector judgment re-audit — 2026-10-28

This is a read-only audit of the original supplied game and a comparison with SYNK. No gameplay rule changes are made in this pass. Original ELF and metadata hashes were rechecked against the retained APK identity. REA native providers remain unavailable on this Windows host; conclusions use retained/re-decoded ARM64 instructions, native constants, generated field offsets and original scene settings. Empty dump method bodies were not used as executable evidence. Original-game runtime and online configuration remain unverified.

## Main corrections to the previous interpretation

| Question | Original behavior established by this audit | Current SYNK difference |
| --- | --- | --- |
| What is judged? | Linked start/continuation/end Note objects in source channels. The yellow RenderLongLine ribbon is drawing, not a continuously scored collision shape. | Path interpolation and visual tracking feedback coexist with per-node checks. |
| Grade of a normal held continuation | Preserves preceding node's JudgeRate and final Judge enum, including terminal continuations. | SYNK preserves middle grades but independently regrades the tail/release. |
| Exact line crossing required? | No. Caller requires PosCali01>.7, then front/rear timing and channel eligibility; before-line credit is possible. | A recent SYNK adjustment requires automatic nodes to reach their timestamp. |
| Leaving a lane | Unreleased Long2 can accept Lost4 for that update. Lost resets next input frame. | SYNK action currently accepts Began/Moved/Held but not Lost. |
| Does every lift produce GOOD? | No such blanket rule was established. Admitted End uses a provisional rate.1, but final enum inheritance can override it. Release-history/missing-predecessor penalty paths can force Good. Initial release-state transitions are not fully resolved. | Earlier reports incorrectly treated provisional rate.1 as unconditional final Good. |
| What does IsLongSlide mean? | Adjacent linked records have the same Tick; both nodes are flagged. It is not every path that changes lane over time. | SYNK's kind=slide denotes a moving path and does not preserve this separate source classification. |
| A real missed node | Marks chain miss/history and propagates MISS to remaining unjudged linked nodes. | Existing chain miss fan-out is broadly retained. |

The earlier statement that a held tail must be independently graded by its own timing error was wrong. Likewise, the rationale that early source eligibility inherently gives a GOOD tail was wrong: the original normally substitutes the predecessor's earned rate and final grade. The recent line-crossing-only change was a SYNK workaround, not recovered original behavior.

## Key instruction anchors

- UpdateViewNotes0x2587AA8..7ADE: eligible long start/current/next-linked node selection;0x2587ADC..7AE8 checks calibrated normalized progress>.7 before call0x2587BB8. That progress threshold is not the judgment line at1.0.
- GetRateLong0x2583140..31C8 and GetRateLongEnd0x25831CC..3254: front/rear window rate. Packaged middle window200ms; head/end300ms. ConfigControl IDs15005..15010 can override timing and grade thresholds online.
- UpdateNoteJudgement0x258A988..A998: unreleased Long2 accepts states1..4, including Lost. The already-released branch0x258A8FC..A960 instead admits1..3 or conditional terminal End5.
- UpdateNoteJudgement0x258AA48..AA88 and0x258AC28..AC38: ordinary unpenalized Long2 substitutes LongPrev.JudgeRate.
- Note.get_IsLongMiddle0x28E1D34: returns NoteType==2, so its name must not be interpreted as excluding the terminal continuation. Note.get_IsLongEnd0x28E1D44 independently tests IsLongNote and LongNext==null.
- UpdateNoteJudgement0x258AAF0..AB18: final predecessor Judge enum inheritance applies to these Long2 continuations, including the tail. History/absent-predecessor branches can force Good.
- LongNoteInfo.MarkSetSlide0x28E1A44..A84: compares Tick(+0x70), setting IsLongSlide(+0x121) only on equal-tick adjacency.
- Existing original autoaim uses the next node's calibrated projected TouchRect2d and the chain's exact IngameTouch object. Per-contact identity fixes in SYNK address actual batching errors; they are distinct from restoring the original grading/state semantics.

The installed239-note13-lane chart and supplied1004_13.seq contain no adjacent equal-tick chain pairs in the bounded scan. Same-tick import preservation matters for other charts but is not established as the cause of this chart's reported misses.

## Remaining boundary and implication

Release history initialization/indirect flag writes have not been completely reconstructed; do not infer that every initial physical release enters the conditional End branch, or that its provisional Good is necessarily its final grade. Current server timing values are also unknown.

A faithful connector restoration should implement linked-node state/grade progression coherently: preserve earned chain grading through the tail, represent transient Lost channel visits, and use the original eligibility flow. It should keep the verified queued-release/finger-identity fixes and preserve chart/draft/recorder data. This investigation does not silently revert the user's later playability choices.

Supporting audits: [caller gates](SSRG_CONNECTOR_CALL_GATES_AUDIT.md), [chain semantics](SSRG_CONNECTOR_CHAIN_AUDIT.md).
