# SSRG gameplay presentation — implementation and boundaries

## Implemented

- Source-art score panel, ordinary and fever gauge frames/labels, actual saved-best readout, card portrait/tier slot, conditional mission/rave/collection displays.
- Six offline fever presentation states. Packaged threshold defaults scale with note count; four source particle banks crossfade for one second with source beam colors and mirrored fever backdrop artwork. All banks are allocated before play. Countdown, resume countdown and pause freeze transitions.
- Miss shake follows source power20, exponent1 and duration0.3 seconds. Repeated misses do not restart an active shake. The objects move horizontally; calibrated touch channels are compensated so visual shake cannot shift their hit rectangles. SYNK OG keeps its existing shake.
- All five special note artwork groups, including six item variants per item level, source beat slot ordering, isolated materials and source B hit flashes. Successful supplied collection events update a real local counter; missed events do not collect.
- Separate SSRG pause controls with resume, retry, song list and speed adjustment. SSRG results use the supplied CLEARED art and actual score/accuracy/combo/grade counts. Auto-play and practice results identify unsaved scores. Retry, replay and practice from detailed results restore the SSRG lane/style context. Regular play remains SYNK OG.
- Responsive safe-area layout checked at1440x640,2400x1080 and1024x768. Original central judgment layout and fixed gold bar are retained.

## Source evidence

REA reopened the supplied `.tools/ssrg-apk-analysis/libil2cpp.so` and verified SHA256 e4ee507e90cc435d0401a4085881a3c322ca8bb306b47b92a389f58762fc053b. A native decompiler is not configured for this ELF on this Windows host; supplementary analysis uses actual retained ARM64 disassembly, pyelftools/Capstone and serialized Unity resources. Empty metadata stubs are not implementation evidence. The original app was not executed.

Serialized level10 IngameRenderer2723: source shake floats at bytes2648..2660 are20,1,.3; target pointer1921 is the Transform of GameObject763 `objects`, which contains the track/notes hierarchy. `PlayMissShake`0x2518f80 ignores a new miss while the old timer is positive; `RenderMissShake`0x2518988 alternates horizontal sign with power(remaining/duration,accel); `StopMissShake` restores zero.

Six serialized FeverFx records begin atbyte7388 with192-byte records. Their source particle references by state are null,null,2720,2722,2719,2721. Beam colors, dark-background alpha, label names/speeds and ordinary sprite base indices are in `scripts/ssrg_presentation_data.gd`; source ordinary indices remain0/12/24 in every state. The complete renderer payload ends9064bytes; FadeOut/FadeIn floats at8864 are both1second. Native FeverFx.SetFadeIn/SetFadeOut/Fade corroborate the linear fade envelope and continued rendering of the fading previous profile.

IngameView static initializer0x258ded8: BaseFeverNoteCount100, FeverLevelEnterCount10, entry thresholds10/12/14/16/16, bonus rates.1/.2/.3/.4, default judgment point values0/.5/1/2. FeverTableData constructor0x258e29c scales thresholds by noteCount/100 and ceilings the10*noteCount/100 entry budget. CalcLifeAndFeverState0x2583984 fills only on native Perfect/SuperPerfect and consumes the nonmiss entry budget; original online configuration can override the defaults.

Level10 note batch2509 contains all84 source sprite slots. SpecialStartIndex[36,48,60,72,78] selects collection, superstar, bomb, item-level1 and item-level2. Item selection and the alternative B hit sequence are source-derived; no SEQ flag meaning or event schedule is guessed. Artwork is cropped from the supplied object/HUD atlases. The explicit preload registry also works in exported Android builds.

## Metadata-dependent presentation

The ordinary local song has no original card inventory, mission, reward or event-server response. It uses its actual song artwork in a clearly marked CUSTOM portrait slot. Supplied cards can replace it. No ownership, reward or source score bonus is invented or written into the user's account. Existing SYNK score/energy rules remain; fever entry starts when that real energy gauge fills. This is an offline presentation adapter, not a claim that the original backend or complete score economy is reconstructed.

An optional `presentation.json` beside a scanned chart can provide:

```json
{
  "cards": [{"portrait": "card.png", "tier": "R"}],
  "card_beats": 4,
  "mission_score": 150000,
  "rave_bonus": 2500,
  "events": [{"order": 17, "type": 0, "item": 0}]
}
```

`order` is the original imported SEQ record order. Types0..4 are collection/superstar/bomb/item1/item2; items0..5 are the source artwork variants. Event attributes are attached only to runtime copies. Card images are copied into app-owned song storage during import. Changing the sidecar hash makes the next ordinary folder scan refresh it. Mission/bonus figures display only when explicitly supplied; a displayed bonus does not add points to SYNK's score. No server-side acquisition or item-rule duration is inferred from the pictures. Malformed/unknown event types are ignored.

The pause/result composition and adaptive640-unit stage canvas are SYNK reconstructions using available source artwork, not a pixel-perfect recreation of every original screen animation. Card rotation uses an explicitly configurable beat cadence. Exact source card-stat/score formulas, mission/reward selection, item gameplay durations and live server overrides remain dependent on unavailable data.

## Validation

Fourteen targeted suites passed: normal/SSRG isolation, source curves, background geometry/pooling, full input integration, presentation transitions, sustain visual clock, sustain integration, touch routing, slide recovery, score HUD, isolated metadata/card-image import and persistence, screen fitting, graphical render alignment and graphical effect timing/layering. Added checks cover event metadata isolation, all special artwork variants, successful versus missed collections, 300ms nonretriggering shake with fixed touch channels, pause freeze, source results and7-lane SSRG retry.

Rendered gameplay, pause, results and tablet results previews were inspected. A12-second desktop sample used the supplied239-note13-lane chart and audio, with a2-second warmup:288 samples, no backward visual-clock steps; frame interval p50/p95=34.790/36.045ms, process monitor p50/p95=38.552/43.050ms. This is Intel UHD770 desktop/window scheduling with a dummy audio fallback, not proof of60FPS or a phone benchmark.

Samsung was not connected during implementation. Normal ADB reconnect and final build/signature status are recorded with the delivered APK. No phone launch, data clearing, uninstall or GitHub publishing is part of this pass.

## Delivered build

Fresh final APK: `builds/android/ssrg-complete-presentation-20261028-235955/SYNK.apk`. Export completed without script/parse/export errors; v2/v3 signatures verified with existing signer SHA256 c9e92947fba79611032b76126c01469c7ded8963d63f41915b7d1ba8791bd467. Exported presentation scripts and special/fever textures were checked inside the APK. ADB reconnect plus an unrestricted device listing both found no Samsung, so transfer, replacement installation and device/runtime comparison remain unavailable. No phone app was launched.
