# Original SSRG connector judgment: caller-gate audit

Audit date: 2026-10-28. Scope is original connector/middle/end eligibility through `UpdateViewNotes` into `UpdateNoteJudgement`, rather than SYNK's current playability adjustments. No gameplay code changed.

## Evidence identity and limits

Retained supplied ARM64 libil2cpp.so SHA256 `e4ee507e90cc435d0401a4085881a3c322ca8bb306b47b92a389f58762fc053b`; metadata SHA256 `39ae1f606d8572219a263f2934c0e8f688de3e2128f7b8513f600552496fccfe`. Both hashes were re-read during this audit. Sources are local Capstone disassembly in `.tools/ssrg-apk-analysis/`, with metadata field/signature mapping from `dump/dump.cs`. Native deep-provider access was unavailable in the preceding investigation; this audit reuses retained evidence and directly decodes source constants/short getters. Original game runtime has not been executed. Online ConfigControl values are unavailable.

## Answer: caller does not require the hit-line crossing

The caller gate is `Note.PosCali01 > 0.7`, **not** `>= 1.0`:

- `UpdateViewNotes` `0x2587ADC..0x2587AE8`: load note+0xB4, compare the value saved at stack+0x14, skip if `<=`.
- Threshold comes from VA `0xF054F4`; bytes `33 33 33 3F` decode to float0.699999988.
- `UpdateNotePosition` `0x25166C0..0x25166D8`: `PosCali01=(viewTopTickReal-TickCali)/viewDuration`.
- `UpdateViewNotes` `0x2587608..0x2587650` adds the view duration to tickReal before the position call. In ordinary constant-tempo seconds, the raw gate is `1+(now-nodeTime)/travel > .7`, i.e. `now > nodeTime-.3*travel`.
- The original speed range1..10 has travel10.5/UI-speed seconds, so the shortest travel1.05s enters this gate315ms early. The packaged200ms middle and300ms end front windows therefore fit inside it throughout that speed range.
- The call at `0x2587BA8..0x2587BB8` passes current `sec` (saved in s10) as the first floating argument. There is no intervening `sec >= node.SecCali` gate on an unjudged eligible connector.

Consequently SYNK's recent `now >= nodeTime` rule for automatic held connectors is a deliberate difference from original SSRG, not a recovered original requirement.

## Which linked node can be judged

The earlier description “each unjudged long node independently” was too broad. The caller's `0x2587AA8..0x2587ADC` and alternate block `0x2587DE0..0x2587DFC` admit a long start/current node or `LongInfo.Current.LongNext`. `Note.get_IsLongCurrent` `0x28E1D64..0x28E1D80` is pointer equality against LongInfo+0x20. Already judged current nodes use UpdateLongTouch; the unjudged eligible next node reaches the judgment callee. `Note.get_IsJudged` `0x28E1D24..0x28E1D30` is `Judge != Max4`.

## Late misses are checked before the callee

For an ordinary unjudged node:

- End: `0x2587B74..0x2587BA4` loads SecCali and `SEC_JUDGEMENT_REAR_LONGEND` (+0x54).
- Middle: `0x2587E20..0x2587E54` loads SecCali and `SEC_JUDGEMENT_REAR_LONG` (+0x4C).
- Common `0x25877C8..0x25877D0` compares `node.SecCali + rear` with current sec. `now <= deadline` continues; `now > deadline` reaches `OnMiss` at `0x2587E00..0x2587E14` for ordinary notes.

Packaged defaults: middle rear200ms, end rear300ms. At the exact rear boundary, the rate is zero and cannot judge, but the caller's MISS waits until time becomes strictly greater.

## State eligibility: Lost is not always rejected

For NoteType.Long2, after the chain-miss rejection:

| Chain branch | Accepted shared track states |
| --- | --- |
| IsReleased false (`0x258A988..0x258A998`) | states1..4: Began, Moved, Use, **Lost** |
| IsReleased true (`0x258A8FC..0x258A960`) | states1..3, or terminal End5 only when `nodeTime-now <= .75*frontEnd` |

The first range is established by `state-1; cmp #3; b.hi reject`; it includes4. The second uses `b.lo` after comparing state-1 with3, so it excludes4, then explicitly tests End5. End-state scoring must therefore be described conditionally; it is not universal for an unreleased chain. Initialization and writers of IsReleased are investigated separately.

Lost is produced when leaving a channel during the current input pass, then reset to Idle at the next enabled UpdateInput. Accepting Lost is thus a **one-update transition allowance**, not an arbitrary wall-clock grace duration. Earlier reports claiming Lost never judges middle nodes are incorrect for the unreleased branch.

## End inheritance: previous report was wrong

An unreleased/uninterrupted actively tracked Long2 end does **not** simply grade its own timing error:

1. `GetRateLong` `0x2583140..0x25831C8` and `GetRateLongEnd` `0x25831CC..0x2583254` first compute positive eligibility using front/rear windows.
2. `UpdateNoteJudgement` `0x258AA04..0x258AA64` routes Long2 nodes through the long-history branch. With no miss/release history, `0x258AC28..0x258AC38` loads `LongPrev.JudgeRate` (+0x50); absent predecessor falls back to rate0.1.
3. `0x258AA68..0x258AA88` uses that substituted rate; `CheckJudgementByTiming` maps it to the grade. Thus the end normally inherits the preceding rate.
4. Every **NoteType.Long2 node, including the terminal node**, additionally passes the preceding-grade override at `0x258AAF0..0x258AB18`. The misleadingly named `get_IsLongMiddle` is only `NoteType == 2` (`0x28E1D34..0x28E1D40`); it does not exclude a terminal node (which is independently identified by LongNext==null). If the predecessor is judged and the forced-history flag w24 is false, the final **enum** becomes the predecessor's Judge. Otherwise the fallback final enum is Good.
5. Accepted End-state handling at `0x258AA28..0x258AA3C` sets release flags and substitutes **rate0.1**, which produces a **provisional** Good in CheckJudgementByTiming. This path initializes w24 to false, so the final Long2 predecessor-enum override can still restore SuperPerfect/Perfect. Therefore accepted End does **not necessarily finish as Good**; JudgeRate and final Judge must be distinguished. The forced-history path sets w24 true and consequently forces final Good.

This corrects the older statement “An actively touched end is timed normally.” It also means the earlier rationale “a held end autojudges at the front edge and therefore earns GOOD” does not describe original SSRG: the eligibility rate is normally replaced by the previous successful node's rate, and the final Long2 grade enum also inherits from the predecessor. Earlier reports saying every accepted End release finishes as Good are likewise too broad: provisional rate0.1 is not necessarily its final grade.

A concrete normal-path counterexample to a line-crossing requirement: previous rate1.0, next middle/end at10.0s, now9.9s, valid Use3, no miss/release flags, travel3.5s. Raw progress≈.971>.7; the node is inside the front window; the source may judge it100ms early and preserve SuperPerfect from the previous rate. No `now>=10` test blocks it.

## IsLongSlide is not a moving-lane classification

`LongNoteInfo.MarkSetSlide` `0x28E1A44..0x28E1A84` compares adjacent nodes' **Tick** at+0x70, not ChannelId. If equal, it sets both notes' IsLongSlide byte+0x121. Ordinary moving chains with different timestamps are not automatically in this branch. Do not equate original IsLongSlide to every SYNK note whose kind is `slide`.

For unjudged non-IsLongSlide Long2, `0x258A9A4..0x258AC08` takes an additional interval-check path before the common rate gate; this still permits before-time points (for example9.9s for a10s node with frontLong.2) and is not a line-crossing-only branch. The IsLongSlide branch reaches the common gate directly.

## Configuration boundaries

`ApplyJudgeTimming` `0x2585990..0x2585A90` obtains front/rear defaults from ConfigControl IDs15005(default),15006(long middle),15007(long end). Metadata and decoded constants confirm packaged .3/.2/.3 seconds; the source can replace them online. Grade-rate IDs15008..15010 likewise override the packaged .00001/.3/.7 values. No claim is made about current server settings or timing changes outside the bounded code traced here.

## Concise original-path pseudocode

```text
UpdateViewNotes:
  update calibrated position
  if unjudged ordinary node and now > SecCali + applicable rear: OnMiss
  else, for a long start/current or Current.LongNext:
    if PosCali01 > .7 and unjudged: UpdateNoteJudgement(now, tick, node)

UpdateNoteJudgement for next Long2:
  reject a missed chain
  choose state eligibility according to IsReleased
  reject already-consumed source channel this update
  compute middle/end front/rear rate; require positive eligible rate
  forcedHistory=false
  if accepted End state: rate=.1; mark release flags
  else if miss/release history: rate=.1; forcedHistory=true
  else: rate=LongPrev.JudgeRate (or .1 if missing)
  map rate to provisional grade
  for Long2 (including terminal):
    if predecessor judged and not forcedHistory: grade=predecessor.Judge
    else: grade=Good
  store channel touch into chain, consume source channel, SetJudgement
```

The pseudocode omits special items, already-judged current-node hold-repeat accounting, and online overrides. It is not a substitute for the conditional assembly ranges above.
