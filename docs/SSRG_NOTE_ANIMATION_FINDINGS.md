# Ordinary note animation and missed holds

Static supplementary ARM64 and serialized resource analysis of the supplied APKs; REA native provider remains unavailable. No target APK execution was used for these findings. Reused retained APK inventory and workspace ELF/Unity extraction, rather than inferring animation from sprite filenames.

## Confirmed source rules

- `IngameRenderer.RenderNote` at RVA `0x251687c`, frame calculation `0x2516a00..2c`: `baseIndex + trunc(beat01 * 11.989999771118164)`. `RenderNote` signature in IL2CPP metadata explicitly names the phase parameter `beat01`; `UpdateViewNotes` forwards its shared beat phase at `0x258887f8..8834`. This is beat-synchronized, not a free-running per-note approach glow.
- Level10 `UIBatchSprite` path2509 serializes 84 sprite entries. The first three ordinary groups each contain twelve entries: `na2,na3,na4,na5,na6,na6,na6,na6,na6,na6,na6,na1`; then the equivalent `nb` and `nc` sequences. Its prefix is `n`. The `na`/`nb` heads are212x116; `nc` continuation/end nodes132x72.
- Ordinary blue taps use `na`; yellow hold starts use `nb`; yellow hold continuation/end nodes use `nc`. Crops come from APK object atlas `854f1945d0bd544bd8c1202cc83e3e6c`, atlas component `016b0b9c6c84f1d47ace4d76eb1f440a` path3, not the older extracted texture set.
- Renderer static initializer `0x251a024`, constants ELF virtual addresses`0xf07930` and`0xf06fa0`: `DarkGray=(.2,.2,.2,.25)` and`White=(1,1,1,.2)` respectively. `RenderNote` uses full white normally. It selects DarkGray when `IsLongNote && LongInfo.IsMiss && (Judge == Miss || !IsJudged)` at`0x2516b18..84`. Already successful chain nodes remain white.
- `RenderLongLine` ending`0x2517010..68` selects DarkGray when its explicit gray parameter is true, otherwise the lower-alpha White constant. This is multiplicative RGB dimming with alpha reduction, not grayscale conversion and not an invented fade duration.
- Correct ordinary connector component is level10 `UIBatchPolySprite` path2512, selected by IngameRenderer serialized reference atbyte320 (native field0x68). It uses object atlas39/path3, prefix`l`, sprite names`1`,`2`,`3`, three UV sets each inset1px on all edges, QuadCapacity3, UVCapacity3. Object atlas chips`l1`,`l2`,`l3` are each6x6 fully opaque uniform RGB(255,199,33),(255,242,111),(255,220,89). Crops are under`note_animation/l1.png` etc.
- `RenderLongLine` produces three overlapping quads: basewidth usesl1, thenwidth+1pixel per side usesl2, thenwidth+2pixel per side usesl3. Packed constant atELF0xf06100 is integer(count3,start0). `UIBatchSpriteSorter.OnFill`0x26b7908..7ff0 iterates quads ascending0,1,2, appending eachgroup's four vertices. Source material uses regular source-alpha blending. Each quad uses normalalpha.2 or missedalpha.25; therefore effective core normalalpha is1-(.8^3)=.488, middleannulus.36, outerannulus.2. They are not separately isolated outline bands.
- An earlier extraction of`Fever_bg line_A-1`/`A-1g` belongs to feverbackgroundpoly2510, **not ordinary long connectors**. Those files are retained temporarily only for integration compatibility; do not use them for ordinary connectors. The exact chips above replace that earlier recommendation.

## Integration

`ssrg_note_animation.gd` provides `artwork(is_long,is_long_start,beat01)`, source `note_tint(...)`, and `connector_tint(chain_missed)`. Use shared song beat phase (freeze it on pause). Replace the synthetic shader approach glow with these source textures for the SSRG renderer. Preserve user-selected hue shifts, sizing, and recorder behavior. Set missed rendering to multiply by the returned color; do not use desaturation as a substitute. Special/event effects are excluded.

Tests cover frame sequence, source dimensions, dimming conditions and connector tint. They do not establish live source game playback or judgment logic.
