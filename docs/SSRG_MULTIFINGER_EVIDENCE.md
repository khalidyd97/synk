# SSRG touch routing and multi-finger arbitration

Static evidence from supplied arm64 `libil2cpp.so`, SHA256 `e4ee507e90cc435d0401a4085881a3c322ca8bb306b47b92a389f58762fc053b`, and IL2CPP metadata SHA256 `39ae1f606d8572219a263f2934c0e8f688de3e2128f7b8513f600552496fccfe`. REA native analysis provider is unavailable on this host. Retained ELF/metadata and Capstone ARM64 decoding supply the evidence below; original-game execution has not been performed. Dump method signatures/field offsets identify storage, while native instructions establish behavior.

## Per-touch autoaim

`IngameTouch.get_ChannelId` at `0x28E0F74` returns `AutoAimChannelId` if it is not -1, otherwise `OriginChannelId`. Autoaim changes channel interpretation; it does not move the finger or alter its physical coordinates.

`SetAutoAim` `0x28E10CC..10E0` stores channel, distance and note reference directly. `ClearAutoAim` `0x28E10B4..10C8` clears note and resets autoaim channel to -1 plus the large initial distance. `Reset` `0x28E1018` also initializes origin/old channels to -1 and marks IsNew. Before each `ContainsTrack`, `UpdateInput` `0x2589C30..C78` refreshes distance to the stored autoaim note's current `Pos2d`.

`ContainsTrack` `0x2589518` first saves the previous effective channel in `OldChannelId`. A touch outside the global track bounds clears autoaim, sets origin channel -1 and returns false (`0x258977C..97B4`). Within the bounds it evaluates autoaim candidates, then determines the physical origin channel from the main rectangles or outer side rectangles. Main rectangles are tested ascending and source channel is `rectIndex * channelInterval` (`0x25899B0..9A28`, `0x2589B10`). At `0x2589AB0..9AEC`, an existing autoaim is cleared only when the origin channel changes **and no eligible autoaim candidate was found in this pass**. Otherwise it is retained. The function returns whether either a valid origin or autoaim candidate exists.

For a Began touch (phase0), candidates are unjudged ordinary notes or long starts, excluding non-start long nodes (`0x2589868..9894`). The touch must be inside `Note.TouchRect2d`. A candidate already stored as AutoAimNote is retained. When choosing another candidate, an absent/end/judged incumbent may be replaced immediately. A larger candidate `Pos01` than the incumbent also permits replacement; otherwise replacement requires a strictly smaller Euclidean distance from touch Pos to candidate Pos2d (`0x25898D8..9988`). Equal distance retains the incumbent. This is not a global nearest-finger search: the candidate search is per finger.

For moved/stationary touches, autoaim candidates are unjudged long nodes excluding starts, on an unmissed chain, whose `LongInfo.Current` is the node or the immediate preceding node (the latter requires a positive GetRateLong). Critically, `LongInfo.Touch` must be the identical touch object (`0x2589624..96BC`). This prefers the already established chain finger when moving between channels. The touch must remain in that node's TouchRect2d. Among valid candidates, an absent/end/judged incumbent can be replaced; otherwise a strictly closer candidate wins (`0x25896C0..9770`). An arbitrary new finger does not gain this active-chain autoaim merely by being close; it can still supply a physical channel to judge/regrab.

## Creation order, not finger ID priority

`get_MakeIngameTouches` `0x258921C..9510` iterates Unity `Input.GetTouch(index)`. Existing non-Began fingers are found by fingerId in the retained pool and updated in place. A Began touch or an otherwise missing finger allocates/reset a touch and appends it. Unreported prior touches become Canceled for one pass, then disappear on the next missing pass.

`FixedPool<object>.Alloc` `0x4090E7C..0F18` appends to the active array. `RemoveAt` `0x409147C..154C` shifts following entries left, preserving their relative order. `UpdateInput` iterates active pool indices ascending (`0x2589C1C..CB8`), with no sorting by finger ID, distance or phase. Thus active creation order persists; simultaneous new touch ordering depends on Unity's GetTouch index order. Later pool entries can overwrite earlier channel assignments when their phase/state branch allows it.

## Shared channel state

TrackInfo stores `State` at offset0x10 and `Touch` at0x18. State values from metadata are Idle0, UseBegan1, UseMoved2, Use3, Lost4, End5, UseOnetime6 (None=-1).

At the start of an enabled input frame (`UpdateInput` `0x2589B80..BE4`), only Lost/End states reset to Idle; other states and touch references persist. Every `trackJudgement[channel]` flag is reset to zero. For each touch, ContainsTrack runs, followed by UpdateInputParse when ContainsTrack returns true. This is a shared per-channel routing pass, followed by note judgments; it is not a permanent exclusive per-chain pointer ownership system.

Equivalent `UpdateInputParse` (`0x2589DB4..9F54`) logic, with `cur = ChannelId`, `old = OldChannelId`:

```text
Began phase0:
    if cur valid: track[cur] = (UseBegan, touch)
    if old valid and old != cur: lose_old()

Moved/Stationary phase1/2:
    if cur valid and (track[cur].state == Use
                     or (old valid and track[old].state in [UseBegan, UseMoved, Use])):
        track[cur] = (Use if old == cur else UseMoved, touch)
    if old valid and old != cur: lose_old()

Ended/Canceled phase3/4:
    if cur valid: track[cur] = (End, null)
    if old valid and old != cur: track[old] = (End, null)

lose_old():
    if track[old].state != End: track[old].state = Lost
    track[old].touch = null
```

No pointer-identity guard appears around these channel writes. A later Began always replaces the channel's earlier touch; a later moved/stationary touch can replace it when the state conditions allow. A later ending touch can clear the shared channel even if a different touch most recently populated it. These are observed source semantics, not an endorsement of broad gesture cancellation handling. SYNK may retain its existing protection against OS-cancel granting a successful tail.

## One channel judgment per frame

`UpdateNoteJudgement` looks up the shared channel track at `0x258A828..A848`. Ordinary heads require UseBegan; long starts allow UseBegan or UseMoved (`0x258A874..A89C`). Long nodes accept source eligible states through their existing chain/release branches. The note code then rejects an already consumed channel (`0x258A89C..A8BC`), captures the channel's current Touch (`0x258A8C0`), and on successful judgment sets `trackJudgement[channel]=1` (`0x258AAC0..AAE8`). For long notes it stores that captured touch into `LongInfo.Touch` (`0x258AAA4..AABC`).

Therefore two overlapping chains do not each independently scan every physical finger and score from the same channel in one original update. Only one successful judgment may consume that channel per input frame, in note traversal order. This is a **frame-local channel gate**, not a permanent one-chain-per-finger rule. A finger's effective channel may serve different notes across later frames, and no exclusive sustain_owner guard was found here.

## Integration and boundaries

Apply central per-frame touch routing for imported SSRG playables, not independent pointer scans for each sustain. Retain per-touch autoaim/physical-origin/old-channel state, touch insertion order, shared channel touch selection and a channel-consumption flag cleared once per gameplay update. Preserve normal SYNK/recorder behavior and chart timestamps. Chain's previous touch should inform moved autoaim eligibility, while the selected channel touch is the one captured on a successful node.

The original game's GetTouch gathering is frame-based; SYNK receives events asynchronously, so batching is an integration adaptation that must be tested with same-frame begin/move/end events. Dynamic UI coordinate conversion and online timing overrides remain external boundaries. Source OS Canceled is parsed like End, but existing SYNK cancel protection need not be regressed. Special-note effects remain excluded.

One additional source boundary: when ContainsTrack returns false after leaving the **global** track bounds, UpdateInput skips UpdateInputParse and calls ContainsGUI. The latter (`0x2589F60..A0F8`) only evaluates a Began pause-button touch; it does not clear the old channel. Thus the observed old-track stale-state edge should not be turned into a claim that every out-of-bounds input scenario is faithfully reproduced. Explicit SYNK cleanup on global exit/cancel is a reasonable documented adaptation; ordinary inside-stage channel changes follow the fully traced parse branches above.
