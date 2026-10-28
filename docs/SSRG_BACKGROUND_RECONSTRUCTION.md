# Original SSRG background reconstruction

## Confirmed static evidence

The four `Perspective2dParticle` components in APK `level10` have their complete serialized profiles in `scripts/ssrg_background_particle_data.gd` (396/436/476/396 bytes consumed). Source artwork is cropped in `assets/ssrg/imported/background/`. The code is ARM64 reconstruction from supplied `libil2cpp.so`, not execution of the original game. Relevant retained disassembly is under `.tools/ssrg-apk-analysis/`.

- `IngameRenderer.LateUpdate` at `0x2518b40..0x2518b6c` and `0x2518c08..0x2518c3c` calls `UnityEngine.Time.get_time`, `UpdateParticles(time,true)`, then `RenderParticles`. These are wall-time particles, not beat-triggered particles. The renderer updates the active FeverFx and fading previous effects; SYNK has no confirmed equivalent fever-state selection.
- `Perspective2dParticle.Reset` at `0x251db08..0x251db68` computes `expected = lerp(countmin,countmax,clamp(density))`, `rangePerFrame = expected/fps*genscale` and a fractional emission accumulator.
- `GenerateParticles` at `0x251dc88..0x251de08` first restores `countmin`, then emits `floor(momentum+Random(0,genscale)*rangePerFrame)`, capped by `countmax`, retaining the fractional remainder.
- `StartParticle` at `0x251e124..0x251e590` samples the weighted degree index list and angular arcs, start radius and depth; its target is the shared center `(0,280,0)`. A shared random factor correlates start distance, depth, color and life. Life is `Random(timemin,timemax)*(1.5-.5*shared)`. Two source polygon units are drawn per particle, using the profile's weighted texture lists and ranges.
- `ResetFactors` clamps descending max ranges to their minimum, including profile4's serialized decel `.05..01` becoming `.05..05`.
- `TranslateParticles` at `0x251df04..0x251df78` removes the particle when raw normalized age reaches cutout, before warping age. Then `q=pow(rawAge,accel)` and, when decel is not1, `q=pow(q,decel/q)`. Position lerps inward from the surrounding ring to the center with q.
- `RenderParticle` at `0x251e7b8..0x251e844` fades color using warped q, not raw age. At `0x251e8b8..0x251e93c` the leading end has halfwidth `height*(pos.z/zmax)/2`. The trailing end is `pos-direction*width*(pos.z/zmax)` and its halfwidth is `height*(pos.z/zmax+trailing.z/zmax)/2`. It is a tapered perspective trail, not a rotated rectangle.

## SYNK application and limits

`ssrg_background.gd` applies source trajectories, profile values, artwork, fade and quad geometry. It groups geometry by texture (two draw calls for stock profile0), bounds live objects by source countmax, and freezes through the explicit pause argument. The source world's UI coordinates map onto the same ground plane as the reconstructed highway.

SYNK runs emission on a fixed60Hz clock instead of coupling density to the device's rendering refresh. It caps catch-up to.25sec to avoid an emission storm after a stall. This is an intentional adaptation, not a recovered native optimization.

Default uses profile0. Profiles1–3 are available to the helper but their fever/rave selection and transition envelope remain unconfirmed. No beat synchronization is invented. Integration preserves existing visual intensity and tint controls. No special-note effects are involved. Native pause time scaling, original GPU material blend equivalence and complete runtime background parity are not established by static checks alone.

`godot_tests/test_ssrg_background.gd` verifies all four profiles construct, source warp values, quad widths, source particle limits and explicit pause freezing. Asset imports and headless checks passed on2026-10-28; a rendered integration check remains the caller's responsibility.
