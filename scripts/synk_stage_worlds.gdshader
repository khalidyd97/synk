shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

// SYNK stage "Worlds": the screen is two worlds split down the highway, warm coral on the
// left and cool violet on the right. Each draws the same pattern of rings, spokes and
// floating tiles around the highway's far end, mirrored, but slid out of place: between
// beats they disagree, and on every beat they snap into one symmetric picture. A miss knocks
// them further apart (`drift`); they pull back together as the player keeps hitting.
uniform vec2 vanish = vec2(0.5, 0.1);
uniform float aspect = 1.7778;
uniform float beat = 0.0;
uniform float energy = 0.0;
uniform float brightness = 1.0;
uniform float drift = 0.0;              // 0 in sync .. 1 far apart
global uniform float synk_time;

const vec3 CORAL = vec3(1.0, 0.38, 0.22);
const vec3 AMBER = vec3(1.0, 0.72, 0.32);
const vec3 VIOLET = vec3(0.56, 0.34, 1.0);
const vec3 ICE = vec3(0.34, 0.62, 1.0);
const vec3 CREAM = vec3(1.0, 0.945, 0.86);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	vec2 p = (UV - vanish) * vec2(aspect, 1.0);
	float side = p.x < 0.0 ? -1.0 : 1.0;
	float kick = exp(-beat * 5.0);
	// How far this world is slid from the shared picture: opposite ways on each side.
	float apart = (1.0 - kick) * (0.22 - 0.08 * energy) + drift * 0.75;
	float slide = side * apart;
	float lock = exp(-apart * 9.0);         // 1 when the worlds agree

	float r = length(p * vec2(1.0, 1.45));
	float angle = atan(p.y, abs(p.x)) / 3.14159;   // mirrored, so both sides match at slide 0
	vec3 warm = mix(CORAL, AMBER, smoothstep(0.0, 1.2, r));
	vec3 cool = mix(VIOLET, ICE, smoothstep(0.0, 1.2, r));
	vec3 ink = mix(vec3(0.075, 0.03, 0.04), vec3(0.03, 0.035, 0.095), smoothstep(-0.12, 0.12, p.x));
	vec3 tone = side < 0.0 ? warm : cool;

	// Rings slide outward on one side and inward on the other.
	float ring_phase = r * 4.5 - synk_time * 0.12 + slide * 0.9;
	float ring = exp(-pow((fract(ring_phase) - 0.5) / 0.045, 2.0));
	// Spokes turn opposite ways.
	float spoke_phase = angle * 9.0 + slide * 1.6;
	float spoke = exp(-pow((fract(spoke_phase) - 0.5) / 0.03, 2.0)) * smoothstep(0.15, 0.5, r);
	// Floating tiles in the cells between rings and spokes.
	vec2 cell = floor(vec2(ring_phase, spoke_phase));
	vec2 local = abs(fract(vec2(ring_phase, spoke_phase)) - 0.5);
	float tile = step(0.7, hash(cell)) * smoothstep(0.34, 0.26, local.x + local.y);
	float twinkle = 0.6 + 0.4 * sin(synk_time * 1.5 + hash(cell + 3.0) * 20.0);

	// Quiet right at the vanishing point, and along the seam under the road.
	float far = smoothstep(0.02, 0.25, r) * smoothstep(0.0, 0.1, abs(p.x));
	vec3 col = ink * (1.0 + 0.6 * smoothstep(1.4, 0.0, r));
	float lines = (ring * 0.5 + spoke * 0.3) * far;
	col += tone * lines * (0.5 + 0.4 * energy + 0.5 * kick);
	col += tone * tile * twinkle * far * (0.16 + 0.14 * energy);
	// In sync, the shared picture burns cream.
	col += CREAM * lines * lock * (0.35 + 0.35 * kick);
	// The seam between the worlds, down the middle, flashes when they meet.
	col += CREAM * exp(-abs(p.x) * 60.0) * lock * kick * 0.25;
	ALBEDO = col * brightness;
	ALPHA = 1.0;
}
