# Score and combo source audit — 2026-11-01

## REA and artifact identity

REA 6.7.0 ran from a workspace-local installation with the already-installed
Node 26 runtime. No client registration or analysis-engine installation changed.
`inspect-artifact` verified the retained `libil2cpp.so`:
SHA256 `e4ee507e90cc435d0401a4085881a3c322ca8bb306b47b92a389f58762fc053b`,
Evidence `ev_983c88eec511e75147ec351bc8d9627f781332a715408f7558afbee6350ee3a8`.
REA's focused native-function request returned `provider_unavailable`:
Ghidra/IDA/Kuna are not configured; Hopper does not support this Windows host.
This inventory establishes identity, not HUD behavior or successful decompilation.

Behavior below comes from supplementary UnityPy serialized-resource inspection
and Capstone decoding of the actual ARM64 instructions, mapped with retained
IL2CPP metadata. Empty dumped C# method bodies were not used as implementation.
Local audit scripts, complete REA output, raw component records, transform chains,
asset rectangles and desktop renders are under `.tools/hud-rea-review/`.
The original game was not launched or modified.

## Score section

Level10 `score_num` is UINumber component2502 on GameObject991. Its Pivot is
Fixed (3), seven child widgets are 30x38 with TopRight pivots, and their
authored right edges after the parent offset are:
249,229,209,179,159,139,109 source units (least significant first).
Their top is84. This replaces the fitted .8 scale/.9 character advance.
`score_text` is68,62 with size92x24, TopLeft pivot. Comma widgets are separate
16x19 sprites at169,105 and99,105, shown above three/six digits respectively.
Native UINumber UpdatePivotPosition exits immediately for Fixed at0x27C9E10;
UpdateEtc0x27C9A30..9BBC controls comma visibility at CommaDigitDistance3.
Existing score digit crops were byte-compared with the bound HUD texture and
all ten matched. The missing `UI_score com` was extracted from atlas rectangle
(2024,587,16,19).

The rave readout now uses the bound ui_rave_T digit, plus and comma artwork;
its digits are26x32 under a .8 parent scale. UINumber component2508 is
Fixed_LeftAlign (4), with stored LSD-first centers135,117,99,76,58,40,14.
UpdatePivotPosition0x27C9E78..9F44 subtracts the next hidden slot position when
available; UpdateEtc positions the plus sign from the leading digit and
SignPadding10. Commas are12x22 under the same .8 parent scale. The label uses
the authored134x30 right-center widget; phase multipliers use32x22 widgets
bound to `rave bonus_x2/x3/x4`.

## Combo counter

The previous shared chrome `s0..9` artwork was not the main HUD font. Scene
bindings establish distinct families:

| Source grade | UINumber | Prefix | Quad size | Centered advance | Tint |
|---|---:|---|---|---|---|
| Super |2497|s|56x90|176/3|RGB .9245283, alpha1|
| Ordinary PERFECT |2507|Text_|56x90|176/3|white|
| GOOD |2501|g|56x90, LSD slot60x90|172/3|white|

These main families bind level10 external49, atlas
`e9fcca575ebb5466992eacfbae18aaaa`, texture
`08a6b66eebe21405bba168de707f5f93` (`ingame_5_hud`,2048x1024).
Original atlas rectangles, including transparent margins, were cropped without
resizing or recoloring to `assets/ssrg/imported/hud/combo/`.

The secondary super layer UINumber2494 uses atlas external58
`02e2601bcb3556c4a9e1885e81d84646`, material
`6071bfd8bcf0cc94ab8517bf79079224`, texture
`2868068ec683da7499c6bee14e25ea73`. Its sprite tint is
(.3607843,.3607843,.3607843,.3607843). The bound shader
`1e81b430fabae5b40a19f8833bb0fe1b` is named
`Unlit/Transparent SrcAlpha One`; both serialized passes specify source blend5
(SrcAlpha), destination1 (One). It is drawn additively behind the main font.

All combo grade parents are at(0,-3) below the logical center; child digits
have centered pivots. UINumber CalculateBounds0x27CA350..A554 and
UpdatePivotPosition0x27C9D9C..A0CC establish the advance from the stored manual
bounds(-116,116), widget width and four-slot capacity. The super clip binds
JudgementGood05; ordinary PERFECT/GOOD bind JudgementGood. Existing recovered
Hermite keys and500ms success lifetime are reused, with the ordinary alpha
track and the super clip's absence of that alpha track respected.

## Limits and adaptations

These are exact packaged artwork bindings, widget sizes, slot coordinates,
colors, blend settings and traced number-layout rules, not proof of identical
live output. SYNK retains its shared640-unit stage/viewport scaling and the
previous video-matched score-group anchor. Original runtime render resolution,
ScreenReducer and live safe-area behavior have not been read from the source
game. A follow-up corrected the super word: two atlases contain a sprite named
Text_perpect_super. The bound HUD version already spells S·PERFECT; the effects
version only spells PERFECT. The synthetic prefix is now removed. See
SSRG_SUPER_WORD_SOURCE_FIX.md for the corrected bindings and colour clip.

The source score widgets have seven slots and combo widgets four. SYNK extends
their spacing for unusually large local counts rather than truncating user
scores/combos; those extensions are adaptations. Scoring and input are unchanged.

## Validation

Source-font/layout, source-curve and score-HUD suites passed. The presentation
integration test's old dedicated-pause expectation was updated to the user's
already-requested shared opaque top-layer pause behavior. Desktop Compatibility
renders were inspected for all three combo grades, score commas, sprite bonus
numbers/multiplier, and pause layering. Android signing/install is performed
separately; the agent does not launch phone gameplay.
