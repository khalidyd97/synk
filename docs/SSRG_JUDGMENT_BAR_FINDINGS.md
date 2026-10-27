# Judgment bar source artwork and gold color

Static serialized APK scene and atlas data, corroborated by native ARM64 SetCardTierColor. No source-game runtime execution claimed.

- Renderer BottomBar field0x208 references bottom UISprite2802, GameObject134. Position(-5,-250,-1), scale(1156,130,1), center pivot4. Sprite Main_black BG3 in object atlas016b0b9c6c84f1d47ace4d76eb1f440a, texture854f1945d0bd544bd8c1202cc83e3e6c.
- Atlas rectangle(294,1795,1136,136), recovered as assets/ssrg/imported/judgment_Main_black_BG3.png. RGB is237 at center with alpha255; vertical alpha gradient and slanted shoulders are source artwork, not synthetic rectangle geometry.
- SetCardTierColor at0x2519774 loads CardTierColors[cardTier+1] at0x25197b0..d4. These scalar RGBA registers remain through vector loads and are passed to BottomBar widget set_color at0x2519880. Tier glow colors are a separate array.
- Renderer2723 serialized CardTierColors starts byte3064, count6. Gold entries4 and5: (1,0.8627451062202454,0.2549019753932953,0.5843137502670288) and same RGB with alpha0.6745098233222961. Gold bar is source artwork multiplied by this gold tint, not a separate gold bitmap. Serialized gray is not the gold tier runtime color.
- User wants fixed judgment color: use gold entry4 as fixed stock appearance and preserve existing customization, instead of adding card-tier-dependent changes.
- bottom_eff UISprite2894 uses same sprite name but separate effect atlas/material, same XY andscale, Z-5005. SetCardTierColor applies CardTierColorsEff RGB while retaining effect alpha. Keep optional flash separate from fixed base color.
- track_bottom texture decorates two lower750x120 elements at x374/-374,y-379. It is not the judgment band.

Crop verification: source outer and inner rectangles are identical (294,1795,1136,136), with zero padding. Neighbor-colored RGB around transparent shoulders/bottom is largely alpha zero. 180 pixels near the rightmost edge have small positive alpha from the source texture; maximum41/255, total weighted area5.46 pixels across154496 pixels. Retain source alpha; these are source texture edge artifacts, not a crop-offset mistake.
