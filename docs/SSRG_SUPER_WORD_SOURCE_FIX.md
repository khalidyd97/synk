# Correct S·PERFECT word and pause placement — 2026-11-01

## Readability correction after user testing

The reconstructed colour loop made the word and combo too dark during coloured
frames, and the effects-atlas PERFECT behind the full S·PERFECT created visible
misaligned lettering. The gameplay display now keeps the complete bound HUD
word white, with a small shadow made from that same sprite. The mismatched
secondary word is removed. Super combo returns to its stable light tint.
The recovered RGB keys remain available as evidence, but are not applied to
the gameplay word/combo. This deliberate readability adjustment supersedes the
rendering description below; the source bindings themselves are unchanged.

This corrects the earlier claim that the complete word was not packaged.
The previous implementation conflated identically named sprites in two atlases.

Level10 jud_super GameObject473 contains trans581. Its main sprite601,
UISprite3092, references external49/path3, HUD atlas
`e9fcca575ebb5466992eacfbae18aaaa`. The texture resource is
`08a6b66eebe21405bba168de707f5f93` (ingame_5_hud). Its Text_perpect_super
rectangle(1586,295,272,54) spells S·PERFECT, including the centered dot.
Decoded RGBA SHA256:
`76a7573bcf08572b3d6ee92372ce7813352dd45c5e276deab6fadbacc7e2bd6d`.
The older supplied STAYC extraction's ingame_5_hud image matches this APK image
as decoded RGBA. The new crop is drawn directly, without a font prefix.

Secondary sprite833/UISprite3251 references external58, the effects atlas,
where the same sprite name is the chrome PERFECT-only image. It is retained
behind the main word with its serialized .3607843 RGBA tint and additive blend.
Both sprite quads are272x54, centered on their parent at UI(0,60).
Animation2418 on jud_super binds external26 JudgementGood05. Its source pop
and500ms word lifetime remain in use.

Animation2429 on trans581 binds external30,
`b7b658a48e322f441a7af5481faab9e2` (JudgementSuperPerfect), with automatic
play and WrapMode2 (Loop). The packaged UnityEngine.WrapMode enum confirms2.
Its legacy stepped RGB keys span .1666666716337204 seconds.
UISpriteColor2547 targets Widget3092 and additional Widgets3247/3079/3162/3141,
the four main super combo digits. IsAlphaOnly=false and ForceAlpha=1.
Native FinalColor0x27CBEA8 returns RGB unchanged and multiplies alpha by
ForceAlpha. Thus the authored colour clip is now applied to both super word
and main combo font. This supersedes the earlier unverified-binding caveat.

The pause sprite is GameObject183/UISprite2834: centered80x85 quad at(44,-63)
relative to the same top-left anchor as the score. SYNK now converts the score
HUD's anchor into the presentation control, then places the icon at rectangle
(4,20.5,80,85) times the shared logical UI scale. The original UI_pause crop
was compared with its bound atlas rectangle(1947,319,80,85) and already matches.
Only placement/aspect were changed; the touch target stays full size.

REA's native RenderJudgement request again returned provider_unavailable.
REA inspect-artifact rejects standalone Unity serialized files as an unsupported
format. Those results are retained locally; neither is claimed as successful
decompilation. The bindings, rectangles and animation properties above were
read with UnityPy and actual ARM64 disassembly against the previously
REA-identified library. No source game was launched.

The source-curve regression checks the source PNG's decoded pixel hash before
Godot's transparent-edge RGB import fix, the bound path, RGB loop and lifetime.
HUD layout tests check the word's source dimensions/center and pause target
placement/aspect. Desktop renders inspect the combined appearance. The common
viewport scale remains an explicit SYNK adaptation; no cross-device runtime
pixel-parity claim is made. Phone gameplay is left to the user.
