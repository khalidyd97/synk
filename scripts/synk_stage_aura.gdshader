shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

// SYNK stage "Aura": a black stage where veils of amber light curl out from the rails.
// Each veil is a slice of a large, slowly turning ring: a faint translucent sheet that
// brightens toward a thin hot edge, with a flare that travels along the edge. Several
// overlap on each side of the highway, each fading in and out on its own time, so the
// light keeps folding over itself like sheets of glass. The flares catch on the beat.
uniform vec2 vanish = vec2(0.5, 0.1);
uniform float aspect = 1.7778;
uniform float beat = 0.0;
uniform float energy = 0.0;
uniform float brightness = 1.0;
global uniform float synk_time;
#include "res://scripts/synk_stage_mask.gdshaderinc"

const vec3 AMBER = vec3(1.0, 0.56, 0.20);
const vec3 EMBER = vec3(0.85, 0.30, 0.10);
const vec3 CREAM = vec3(1.0, 0.92, 0.78);
const int VEILS = 6;

float hash(float n) { return fract(sin(n * 127.1) * 43758.5453); }

void fragment() {
	vec2 p = (UV - vanish) * vec2(aspect, 1.0);
	float side = p.x < 0.0 ? 0.0 : 1.0;
	vec2 q = vec2(abs(p.x), p.y);           // both sides share the shapes, mirrored
	float kick = exp(-beat * 5.0);
	float t = synk_time;

	vec3 col = vec3(0.004, 0.003, 0.005);
	for (int i = 0; i < VEILS; i++) {
		float n = float(i) * 7.3 + 1.0;
		// Each side runs on its own clock, so the two are alike but never identical.
		float clock = t * (0.16 + 0.10 * hash(n + 5.0)) + hash(n) * 30.0 + side * 3.7;
		vec2 centre = vec2(0.10 + 0.50 * hash(n + 1.0), 0.18 + 0.42 * hash(n + 2.0))
			+ 0.06 * vec2(sin(clock * 1.3), cos(clock * 0.9));
		float radius = 0.26 + 0.34 * hash(n + 3.0) + 0.03 * sin(clock * 0.7);
		float width = 0.07 + 0.13 * hash(n + 4.0);
		vec2 d = q - centre;
		float r = length(d);
		float angle = atan(d.y, d.x);
		// The slice of the ring that is lit turns slowly.
		float facing = -1.5708 + (hash(n + 6.0) - 0.5) * 2.2 + 0.7 * sin(clock);
		float turn = abs(mod(angle - facing + 3.14159, 6.28318) - 3.14159);
		float slice = smoothstep(1.15, 0.25, turn);
		// It breathes in and out over several seconds.
		float life = pow(0.5 + 0.5 * sin(clock * 1.9 + hash(n + 7.0) * 6.28), 1.6);
		// A translucent sheet, faint on the inside and brighter toward its outer edge.
		float across = clamp((r - (radius - width)) / width, 0.0, 1.0);
		float sheet = across * across * step(r, radius) * 0.26;
		// The hot edge, with a flare sliding along it.
		float edge = exp(-pow((r - radius) / 0.0045, 2.0)) + 0.35 * exp(-pow((r - radius) / 0.02, 2.0)) * step(r, radius);
		float flare_at = facing + 0.6 * sin(clock * 2.3 + 1.0);
		float flare_turn = abs(mod(angle - flare_at + 3.14159, 6.28318) - 3.14159);
		float flare = exp(-pow(flare_turn / 0.22, 2.0));
		float glow = slice * life * (0.65 + 0.35 * energy);
		col += mix(EMBER, AMBER, across) * sheet * glow;
		col += AMBER * edge * glow * (0.3 + 1.2 * flare * (0.7 + 0.6 * kick));
		col += CREAM * edge * flare * flare * glow * (0.25 + 0.35 * kick);
	}
	// A faint warm haze near the highway, so the veils seem to rise from the rails.
	float haze = exp(-length(q - vec2(0.25, 0.35)) * 3.2) * (0.05 + 0.03 * kick + 0.03 * energy);
	col += EMBER * haze;
	// Nothing is drawn under the highway.
	ALBEDO = mix(vec3(0.0), col, road_mask(UV)) * brightness;
	ALPHA = 1.0;
}
