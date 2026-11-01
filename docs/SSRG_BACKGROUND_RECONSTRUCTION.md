# Original SSRG background reconstruction

## Rail-edge coverage and album card (2026-11-01 follow-up)

Supersedes the earlier triangular entrance mask below. The veil now samples
the same mirrored rail sprite at its exact UI placement and uses its opaque
dark road pixels as the mask. This reaches the inner rail bevel without a
geometric gap; bright rail pixels and transparent exterior pixels are excluded.
The veil retains priority 3 so it still covers distant notes and hold tails.
Desktop shadow-on/off checks preserved the sampled white rails and confirmed
darkening immediately inside the upper rail edges.

The SSRG album tile now occupies the top-center card slot (20% of safe-area
height, capped at 170 UI pixels), aligned through the highway's projected
entrance into the cover's safe-area coordinates. Loading-to-play and
play-to-results transitions use the shared target rectangle. Other highway
styles retain their corner album tile. Layout/glide tests passed at 1564x720,
2400x1080 and 1024x768; artwork-loading and screen-fitting suites also passed.

Pause now uses a fully opaque dark backdrop and rounded opaque panel rather
than screen-reading blur shaders. The backdrop is opaque immediately on entry;
the menu itself retains its entrance animation. Targeted pause and edge-to-edge
checks passed and the layout was rendered on desktop. The broader `test_game`
suite encountered old countdown/section expectations and stopped at its obsolete
`lobby.DragScroll` property access, before reaching its pause checks; it is not
reported as passing.

## Entrance shadow rail mask (2026-11-01)

The entrance veil still draws over distant notes, as requested. Its horizontal
mask now stays inside the original rail sprite's inner edges: on the 1440x600
veil plane, normalized half-width is `max(0, depth*.8-.008)` with an inward
.008 feather. The previous `depth+.025` mask extended across the rails.
Draw order is retained. Desktop renders with the shadow enabled/hidden had
identical RGB at 12 sampled rail-center points (six heights on each side).

## SMTOWN-style laser presentation (2026-11-01)

At the user's request, the background shader now presents the retained source
trajectories as thin light streaks. Near/far half-widths are multiplied by .6
and capped at 1.6 logical units, preventing the depth-derived trailing end from
becoming a large wedge. Additive blending and feathered edges/ends replace the
previous hard alpha-blended strip. Source textures retain rave-profile colours;
custom tint and intensity controls still apply. Emission, density, batching,
pause handling and gameplay are unchanged.

This is a visual adaptation inspired by SMTOWN, not a recovered SMTOWN shader
or a claim of exact runtime parity. All four profiles were rendered and
inspected on the desktop Compatibility renderer. The existing background
profile/geometry/capacity/pause suite passed. Phone gameplay is left to the user.

## Reference-photo correction (2026-10-29)

The retained `ssrg-reference-video.jpg` and `ssrg-motion-3.png` show the Ultra
Rave magenta wash concentrated around the screen perimeter, with the song photo
clearer in the middle. The cropped `Fever_bg_1..4` quarter textures have their
strong alpha at (0,0) and weak alpha at (1,1). The cover shader previously mapped
the strong corner into the screen center. It now maps each outer screen corner
to (0,0) and the center to (1,1). All four rave levels were rendered and visually
checked on desktop. This fixes the reversed color gradient; it does not establish
complete runtime parity with SSRG or constitute a phone play test.

Follow-up: clamp all four quarter-texture samplers at their borders. Wrapping
at the mirrored center sampled the opposite, opaque border and drew a cross.
The user-requested rave pulse now modulates overlay alpha from 65% to 100%
using the existing cosine song-beat clock, which freezes during pause. The
one-second state entrance uses smoothstep easing and alpha-weighted color
mixing, avoiding a second multiplication of fade weight into the color. This
pulse is a requested presentation adjustment, not a recovered native timing rule.

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
