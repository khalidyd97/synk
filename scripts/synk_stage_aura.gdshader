shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

// SYNK stage "Aura", after the highway design guide's upper layers, on black:
//   - Arc ribbons: soft silk ribbons of amber light that flow in slow S-curves beside the
//     rails, each a fine bright line with a veil trailing off one side.
//   - Arc particles: small glassy shards, lit along one edge, drifting and turning.
//   - Background vignette: a low amber glow in the bottom corners.
// Both sides share the shapes, mirrored, but run on their own clocks. The ribbons' bright
// crests catch on the beat.
uniform vec2 vanish = vec2(0.5, 0.1);
uniform float aspect = 1.7778;
uniform float beat = 0.0;
uniform float energy = 0.0;
uniform float brightness = 1.0;
global uniform float synk_time;
#include "res://scripts/synk_stage_mask.gdshaderinc"

const vec3 AMBER = vec3(1.0, 0.55, 0.18);
const vec3 EMBER = vec3(0.80, 0.30, 0.08);
const vec3 WARM = vec3(1.0, 0.86, 0.62);
const int RIBBONS = 4;
const int SHARDS = 5;

float hash(float n) { return fract(sin(n * 127.1) * 43758.5453); }

void fragment() {
	vec2 p = (UV - vanish) * vec2(aspect, 1.0);
	float side = p.x < 0.0 ? 0.0 : 1.0;
	vec2 q = vec2(abs(p.x), p.y);           // x: out from the centre line, y: down the screen
	float kick = exp(-beat * 5.0);
	float lift = 0.75 + 0.35 * energy;

	vec3 col = vec3(0.0);
	// Background vignette: amber rising from the bottom corners.
	float corner = length((UV - vec2(side, 1.0)) * vec2(aspect * 0.8, 1.0));
	col += EMBER * exp(-corner * 2.6) * (0.20 + 0.05 * kick + 0.08 * energy);

	// Arc ribbons.
	for (int i = 0; i < RIBBONS; i++) {
		float n = float(i) * 9.1 + 2.0;
		float clock = synk_time * (0.10 + 0.06 * hash(n)) + hash(n + 1.0) * 40.0 + side * 5.3;
		// The ribbon's path: a slow S-curve across the space beside the highway.
		float base = 0.12 + 0.46 * hash(n + 2.0) + 0.05 * sin(clock * 0.8);
		float wave = 1.6 + 1.8 * hash(n + 3.0);
		float sway = 0.10 + 0.08 * hash(n + 4.0);
		float path = base + sway * sin(q.x * wave + clock * 2.0) + 0.035 * sin(q.x * wave * 2.6 - clock * 3.1);
		float slope = sway * wave * cos(q.x * wave + clock * 2.0);
		float d = (q.y - path) / sqrt(1.0 + slope * slope);   // distance from the ribbon
		// It is lit along one stretch, which drifts out and back.
		float reach = 0.55 + 0.35 * sin(clock * 1.4 + hash(n + 5.0) * 6.28);
		float stretch = exp(-pow((q.x - reach) / (0.30 + 0.15 * hash(n + 6.0)), 2.0));
		float life = pow(0.5 + 0.5 * sin(clock * 1.7 + hash(n + 7.0) * 6.28), 1.4);
		float line = exp(-pow(d / 0.0028, 2.0));
		// The silk veil hangs off one side of the line and thins out.
		float hang = hash(n + 8.0) < 0.5 ? d : -d;
		float veil = exp(-max(hang, 0.0) / (0.05 + 0.05 * hash(n + 9.0))) * step(0.0, hang) * 0.22;
		// The crest where the ribbon turns burns brightest.
		float crest = pow(1.0 - min(1.0, abs(slope) * 4.0), 2.0);
		float glow = stretch * life * lift;
		col += mix(EMBER, AMBER, stretch) * veil * glow;
		col += AMBER * line * glow * (0.45 + 0.9 * crest);
		col += WARM * line * crest * glow * (0.35 + 0.5 * kick);
	}

	// Arc particles: kite-shaped shards of glass.
	for (int j = 0; j < SHARDS; j++) {
		float n = float(j) * 5.7 + 60.0;
		float clock = synk_time * (0.07 + 0.05 * hash(n)) + hash(n + 1.0) * 50.0 + side * 2.9;
		vec2 centre = vec2(0.28 + 0.75 * hash(n + 2.0), 0.08 + 0.55 * hash(n + 3.0))
			+ 0.07 * vec2(sin(clock * 1.9), cos(clock * 1.3));
		float turn = hash(n + 4.0) * 6.28 + 0.5 * sin(clock * 1.1);
		vec2 l = q - centre;
		l = vec2(l.x * cos(turn) - l.y * sin(turn), l.x * sin(turn) + l.y * cos(turn));
		float size = 0.035 + 0.05 * hash(n + 5.0);
		// A kite: long toward one tip, short toward the other.
		float along = l.x / (size * (l.x > 0.0 ? 1.6 : 0.7));
		float across = l.y / (size * 0.42);
		float kite = 1.0 - (abs(along) + abs(across));
		if (kite > 0.0) {
			float life = pow(0.5 + 0.5 * sin(clock * 2.3 + hash(n + 6.0) * 6.28), 2.0);
			// A glass facet: nearly clear on one face, glowing toward the lit edge.
			float facet = smoothstep(-1.0, 1.0, across) * 0.35 + 0.05;
			float rim = smoothstep(0.10, 0.0, kite) * step(0.0, across);
			col += mix(EMBER, AMBER, facet) * facet * life * lift * 0.8;
			col += WARM * rim * life * lift * 0.6;
		}
	}
	// Nothing is drawn under the highway.
	ALBEDO = mix(vec3(0.0), col, road_mask(UV)) * brightness;
	ALPHA = 1.0;
}
