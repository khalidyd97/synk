shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

// SYNK stage "Aura", after the highway design guide's upper layers, on black:
//   - Arc ribbons: soft silk ribbons of amber light that flow in slow S-curves beside the
//     rails, each a fine bright line with a veil trailing off one side.
//   - Background vignette: a low amber glow in the bottom corners.
// Both sides share the shapes, mirrored, but run on their own clocks. The ribbons follow
// the music: the bass swells and brightens them, the mids send a ripple along them, and
// their bright crests catch on the beat.
uniform vec2 vanish = vec2(0.5, 0.1);
uniform float aspect = 1.7778;
uniform float beat = 0.0;
uniform float energy = 0.0;
uniform float bass = 0.0;    // 0..1, the song's low end right now
uniform float mids = 0.0;    // 0..1, the song's melody range right now
uniform float brightness = 1.0;
global uniform float synk_time;
#include "res://scripts/synk_stage_mask.gdshaderinc"

const vec3 AMBER = vec3(1.0, 0.55, 0.18);
const vec3 EMBER = vec3(0.80, 0.30, 0.08);
const vec3 WARM = vec3(1.0, 0.86, 0.62);
const int RIBBONS = 4;

float hash(float n) { return fract(sin(n * 127.1) * 43758.5453); }

void fragment() {
	// True screen position (0..1, y down), whatever the backdrop quad's size.
	vec2 at = SCREEN_UV;
	vec2 p = (at - vanish) * vec2(aspect, 1.0);
	float side = p.x < 0.0 ? 0.0 : 1.0;
	vec2 q = vec2(abs(p.x), p.y);           // x: out from the centre line, y: down the screen
	float kick = exp(-beat * 5.0);
	float lift = 0.60 + 0.35 * energy + 0.85 * bass;

	vec3 col = vec3(0.0);
	// Background vignette: amber rising from the bottom corners.
	float corner = length((at - vec2(side, 1.0)) * vec2(aspect * 0.8, 1.0));
	col += EMBER * exp(-corner * 2.6) * (0.20 + 0.05 * kick + 0.08 * energy);

	// Arc ribbons.
	for (int i = 0; i < RIBBONS; i++) {
		float n = float(i) * 9.1 + 2.0;
		float clock = synk_time * (0.10 + 0.06 * hash(n)) + hash(n + 1.0) * 40.0 + side * 5.3;
		// The ribbon's path: a slow S-curve across the space beside the highway.
		float base = 0.12 + 0.46 * hash(n + 2.0) + 0.05 * sin(clock * 0.8);
		float wave = 1.6 + 1.8 * hash(n + 3.0);
		float sway = (0.10 + 0.08 * hash(n + 4.0)) * (1.0 + 0.30 * bass);
		float path = base + sway * sin(q.x * wave + clock * 2.0) + 0.035 * sin(q.x * wave * 2.6 - clock * 3.1)
			+ 0.012 * mids * sin(q.x * 13.0 - synk_time * 7.0 + hash(n) * 6.28);
		float slope = sway * wave * cos(q.x * wave + clock * 2.0);
		float d = (q.y - path) / sqrt(1.0 + slope * slope);   // distance from the ribbon
		// It is lit along one stretch, which drifts out and back.
		float reach = 0.55 + 0.35 * sin(clock * 1.4 + hash(n + 5.0) * 6.28);
		float stretch = exp(-pow((q.x - reach) / (0.30 + 0.15 * hash(n + 6.0)), 2.0));
		float life = pow(0.5 + 0.5 * sin(clock * 1.7 + hash(n + 7.0) * 6.28), 1.4);
		float line = exp(-pow(d / (0.0028 * (1.0 + 0.9 * bass)), 2.0));
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

	// Nothing is drawn under the highway.
	ALBEDO = mix(vec3(0.0), col, road_mask(at)) * brightness;
	ALPHA = 1.0;
}
