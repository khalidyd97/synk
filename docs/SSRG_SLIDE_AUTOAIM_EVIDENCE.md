# SSRG moving sustain autoaim rectangles

Source: operator-supplied `split_config.arm64_v8a.apk`, `lib/arm64-v8a/libil2cpp.so` SHA256 `e4ee507e90cc435d0401a4085881a3c322ca8bb306b47b92a389f58762fc053b`; metadata SHA256 `39ae1f606d8572219a263f2934c0e8f688de3e2128f7b8513f600552496fccfe`. REA native provider is unavailable. The findings below come from the retained ARM64 Capstone disassembly, verified native constants, metadata field offsets and serialized level10 settings. Empty generated method bodies are not evidence of behavior. This is static evidence; the original app has not been executed.

## Rect construction — answered

`IngameRenderer.UpdateNotePosition` at `0x2516340` calculates calibrated normalized progress from `TickCali` and the view duration (`0x25166CC..66D8`), then applies the perspective acceleration (`0x25166F4..6704`). The supplied settings have acceleration6. It samples `SampleTopToBottomCen(channel, q)` into `Note.PosCali2d` (`0x2516728..6738`). The sampling implementation at `0x251F22C` is `TopPos + TopToBottomCen[channel] * q`.

At `0x25167F4..6864`, touch size and rectangle are:

```text
q = pow((viewTopTickReal - TickCali) / viewDuration, 6)
center = TopPos + TopToBottomCen[node.ChannelId] * q
touch_size = NoteScaleMaximum.xy * q * (1.1, vertical_factor)
vertical_factor = 2.5 for long middle or long end, otherwise 2.0
TouchRect2d = Rect(center - touch_size * 0.5, touch_size)
```

The native constant at VA `0xF0531C` is float1.100000023841858. The source level10 logical `NoteScaleMaximum.xy` is212x116, despite a continuation/end sprite drawing at132x72. Therefore a long middle/end's touch rectangle is233.2q by290q source UI units. Its center is the upcoming node's own projected/calibrated position, **not** an interpolated point along the drawn connector. Source `TopPos=(0,280)`; bottom channel centers have x approximately(channel-6)*62.7139231364 and y=-234, so center.y=280-514q. At q=1, center.x is that node's judgment-line channel center. There is only small source floating-point noise around the middle channel's nominal x=0.

`UpdateViewNotes` adds the view duration to the incoming current tick before passing `viewTopTickReal` (`0x2587638`). At fixed tempo this is equivalent to `q=pow(1+(now-nodeCalibratedTime)/travelSeconds,6)`. The geometry uses the calibrated tick directly, not the uncalibrated rendered center or a SYNK smoothed visual clock. There is no clamp in the inspected native progress/acceleration path; q can exceed1 after the scheduled hit time. A nonnegative-base clamp before appearance is a SYNK boundary adaptation, immaterial within the recovered200ms autoaim window at normal travel durations.

This rectangle path does not multiply by renderer `noteScale`. Visible `Size2d`/`RenderSize2d` do use that scale earlier in the same function (`0x251673C..67C4`), but `TouchSize2d` reloads the base `NoteScaleMaximum` and calibrated progress independently. It does not use the 4/7/13 channel collider width either. User artwork scaling must not enlarge this recovered autoaim rectangle.

All native rectangle comparisons include the minimum and exclude the maximum (`0x25896C0..96FC`).

## Moving/stationary sustain eligibility — answered

`IngameView.ContainsTrack` at `0x2589518` treats Unity TouchPhase0 (Began) separately from phases1/2 (Moved/Stationary). The moving/stationary scan at `0x2589624..967C` excludes judged notes, long starts, ordinary notes and chains whose `LongInfo.IsMiss` is set.

`LongInfo.Current` is the last successfully judged linked node: `Note.OnJudgement` stores the judged node at long-info offset0x20 (`0x28E2114..213C`). The scan accepts an unjudged candidate only if it is Current itself or `Current.LongNext`. Since judged candidates were already excluded, normal successful progression targets the **next linked node**.

For `Current.LongNext`, `GetRateLong(now, node.SecCali)` must be strictly positive (`0x2589698..96A8`). `GetRateLong` at `0x2583140` computes1 minus absolute timing error divided by the front/rear middle window. Packaged defaults are200ms each; the boundary is strict. This autoaim eligibility calls the middle-window function even for a terminal candidate. Terminal judgment still retains its separately recovered terminal timing/release rules.

The candidate's `LongInfo.Touch` must be the exact same `IngameTouch` object as the finger being parsed (`0x25896B4..96BC`). A replacement finger therefore does not receive this owner-only moving autoaim merely by being close to a slide. It must first enter through ordinary channel/touch arbitration and establish the appropriate chain contact. No arbitrary re-grab grace duration is inferred here.

The finger must lie inside that node's `TouchRect2d`. A qualifying candidate sets autoaim to its ChannelId and Note (`0x2589760..9770`). Existing qualifying autoaim stays selected when the existing candidate is still the same node; otherwise a candidate can replace it if there was no previous autoaim, the previous aim note was an end/already judged, or its center is closer than the stored autoaim distance (`0x2589700..975C`). Distance is measured to `Note.Pos2d` (uncalibrated rendered center), while containment uses `PosCali2d`.

`IngameTouch.get_ChannelId` at `0x28E0F74` returns AutoAimChannelId when it is not-1, otherwise OriginChannelId. `SetAutoAim` at `0x28E10CC` stores channel, distance and note. Native global touch bounds and source side rectangles remain independent prerequisites/fallbacks; the rectangle must not allow touches arbitrarily outside the highway input region.

## Global bounds — answered

`ContainsTrack` checks `IngameView.TouchTrackArea` at field0x268 before autoaim or ordinary channel lookup (`0x2589598..95D8`). The source level10 `IngameView` MonoBehaviour path3109 is1328 raw serialized bytes. Its Renderer PPtr `(fileID=0,pathID=2723)` is at object offset664. The next16 bytes at676 decode as `TouchTrackArea=(-610.6000366210938,-319.0400085449219,1221.2000732421875,444.7200012207031)`.

This parse is corroborated by the following six source collider PPtr arrays beginning at692: counts4,2,7,2,13,2, with pathIDs within2318..2347 and the expected4/7/13 main/side groupings. Those fields directly follow the Rect in metadata. The source global bounds are therefore approximately **x[-610.60004,610.60004), y[-319.04001,125.67999)**. They must not be substituted by the main channel collider's y[-449,1) band: that band is only for origin channel assignment. Owner autoaim may succeed above y=1 while below125.68. Conversely, the global gate rejects y below-319.04 even if an individual main collider extends lower.

## Implementation guidance and limits

Apply these rules to imported SSRG sustained-note routing only. Keep normal SYNK and recorder handling unchanged. Preserve chart timestamp/lane data, ordinary head/tap timing, and the fixed gold bar. Test a currently owned slide near its next node, a displaced finger inside/outside the rectangle, the strict middle-window boundary, distinct4/7/13 base channels, user note-size changes, replacement fingers, crossing chains, released pointers and expired chains.

This report answers the rectangle/formula/owner eligibility question. Source per-frame arbitration between competing fingers and per-channel input states is a separate investigation. It does not establish complete device/runtime parity, dynamic tempo/calibration equivalence, or online timing overrides.
