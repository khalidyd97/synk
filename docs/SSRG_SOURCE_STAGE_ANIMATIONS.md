# Packaged stage animations

Static evidence from the supplied `split_base_assets.apk`, Unity `level10` external resource bindings; no original-game runtime execution. The existing REA native provider is unavailable on this host, so this pass reused its retained package evidence and used scoped UnityPy resource parsing and retained ARM64 disassembly. Empty IL2CPP method stubs are not treated as implementation.

## Applied authored curves

`scripts/ssrg_source_curve_data.gd` retains source resource names, SHA256 hashes and keyframes (time, value, incoming tangent, outgoing tangent). `ssrg_runtime_curves.gd` evaluates ordinary unweighted cubic Hermite keys and source stepped color keys. All selected source curves have weightedMode0. This avoids substituting a generic easing curve.

- Every `laser_00..12` Animation references level10 external3, `a80c69c4f5a1849bd9e6f5f8afef1072`, clip `alpha_out_linear`: alpha1 at0, alpha0 at1 with linear−1 tangents. Native `IngameRenderer.Awake`0x2515260 sets the TouchTrackOut animation states at field0x248 to speed10. Effective release is **100ms**. `RenderTrack`0x251864C starts release while alpha1, checks AutoHide afterward, and cancels release/restores alpha1 on an active touch. Integration must retain released lane/channel state so a different touch does not inherit its fade.
- Judgments `jud_good`, `jud_perfect` and `combo_perfect` bind external13, `cee1fa4cc260b44c49079c5654b6fc7f`, clip `JudgementGood`. `combo_super` binds external26, `bc2995f758c197e4ab6c8f3ff94cc17b`, `JudgementGood05`. Both have identical authored scale keys:1.6 at0,1 at83.333ms,.7 at116.667ms,1 at150ms, then1 at500ms. Separate X/Y tangents are retained. Judgment sprite alpha starts.2 and reaches1 at50ms. Good05 has no alpha track.
- Miss `jud_miss` binds external35, `a7a47ecc6eb784e0ba744bd1f6bbd76e`, `JudgementBreak`. Scale starts(2.4,.2) and reaches(1,1) at83.333ms. Position stays0 until833.333ms and moves down10 source units by1sec. This is a text response; no red screen bar is restored.
- SSRG display uses these pop curves for judgment art and combo digits. Internal SYNK GREAT displays the source ordinary PERFECT name; internal PERFECT retains S·PERFECT art. Existing SYNK text lifetime and persistent combo behavior are preserved because the complete source widget auto-hide/lifetime call chain was not established in this pass.

`godot_tests/test_ssrg_source_curves.gd` checks source key values, linear beam decay and stepped/Hermite sampling. Helper and HUD parse checks pass. Builds and visual integration validation belong to the parent task.

## Retained evidence, not claimed exact implementations

- `JudgementSuperPerfect` external30 `b7b658a48e322f441a7af5481faab9e2` contains abrupt RGB flicker keys over166.667ms. Its binding to the selected top-level grade artwork needs verification before enabling flashing recolors.
- Side balls and side effects bind external6 `627bfcaab07cb4ed6985a3e7f900c5a4`, `alpha_beat_pingpong_smooth`. Keys span0..2sec even though legacy muscle default stopTime is1; changing actual playback speed and source beat synchronization requires inspecting the animation-state call sites. Do not infer a1sec loop from muscle metadata.
- Four `Perspective2dSphereSettings`/`Perspective2dParticle` components exist. Native motion, count, spawn lifecycle, palette by rave level, and alpha interaction are not recovered here. Existing background lasers are retained, not relabeled an exact APK particle reconstruction.
- `pause_continue` external29 `515a476bbfa93ae409c51b951316227a` contains3/2/1 steps spaced1sec, each3x→1x over166.667ms and fade overthe final166.667ms. Source countdown layout/paused audio interaction is not established; existing two-second entrance is a user-requested design.
- `UIRoot.activeHeight` native formula and clamping were recovered earlier. ScreenReducer can alter render resolution, so enabling native automatic pixel scaling without recovering its device-dependent selection would regress the video-matched640logical canvas. Keep current proportional viewport scaling and centered640canvas.

The excluded special-note/item effects are not added. Ordinary judgment animation is independent of special-note effects.

## Follow-up: exact ordinary judgment artwork

The source UISprite bindings on level10 child sprites identify atlas external49/path3 (`e9fcca575ebb5466992eacfbae18aaaa`). It references material `399b57a35cf754a419601a7f2280779e` and texture `08a6b66eebe21405bba168de707f5f93`, `ingame_5_hud`,2048×1024. Source atlas rectangles (top-left coordinates) are Text_good(1619,358,180,54), Text_perpect(1313,323,272,54), Text_miss(1800,350,146,54). Crops were visually checked. The new PNGs retain original gold PERFECT, cyan GOOD, and pink MISS appearance, removing fallback plain labels for these grades.

Source judgment parent positions are y60 for good/perfect/super, y45 for miss. Their sprite child scales are180×54,272×54,272×54 and192×70 respectively; miss child positiony−50 gives final y−5,65sourceunits below ordinary judgment. Source pivot4 is centered. SYNK keeps the accepted central word/combo layout and44pixel reference word height but follows relative source word dimensions and miss placement.

Native `EndRender`0x251849C calls AnimationAutoHide for each Judges(field0xb8) word. At0x25184D0 onward it checks whether any nonmiss judgment remains active and hides combo widgets once none remain. Source word/combo do not persist indefinitely. Source legacy Good and Good05 curves end500ms and Break curves end1sec; their muscleClipSize0 means the synthetic muscle stopTime1 is not a populated muscle payload. Runtime Unity clip-length confirmation is still unavailable; deriving500ms/1sec from final authored keys is explicitly an inference.
