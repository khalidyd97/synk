shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

// SYNK mode's stage: a backdrop that moves with the music, drawn on the screen-filling
// quad behind the highway (UV is screen space, y down). In place of SSRG's lasers, fever
// art and rail effects:
//   - a coral-and-amber sunrise where the highway meets the horizon, swelling on the beat
//   - sync waves: cream rings rippling out from that point, one born every beat
//   - a sound equaliser: light bars rising up both sides of the screen, new heights each beat
//   - drifting four-point sparkles, the mark on SYNK's notes
// `energy` (0 calm .. 1 full rave) makes all of it brighter and busier.
uniform vec2 vanish = vec2(0.5, 0.1);   // the highway's far end on screen
uniform float aspect = 1.7778;
uniform float beat = 0.0;               // 0..1 through the current beat
uniform float beat_count = 0.0;         // whole beats so far
uniform float energy = 0.0;
uniform float brightness = 1.0;
global uniform float synk_time;

const vec3 INK = vec3(0.035, 0.026, 0.055);
const vec3 DUSK = vec3(0.13, 0.055, 0.17);
const vec3 CORAL = vec3(1.0, 0.42, 0.24);
const vec3 AMBER = vec3(1.0, 0.76, 0.42);
const vec3 CREAM = vec3(1.0, 0.945, 0.86);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	vec2 uv = UV;
	vec2 p = (uv - vanish) * vec2(aspect, 1.0);
	float r = length(p);
	float kick = exp(-beat * 5.0);          // 1 on the beat, decaying through it

	// Sky: ink at the top, a dusky violet lower down, warmer toward the horizon.
	vec3 col = mix(INK, DUSK, smoothstep(0.0, 1.0, uv.y) * 0.8);
	col += CORAL * exp(-abs(uv.y - vanish.y) * 9.0) * (0.04 + 0.03 * energy);

	// Sunrise at the vanishing point.
	float sun = exp(-r * (5.0 - 0.8 * kick - 0.8 * energy));
	col += mix(CORAL, AMBER, exp(-r * 8.0)) * sun * (0.2 + 0.18 * kick + 0.14 * energy);

	// Sync waves: flattened rings, one born each beat, fading as they spread.
	float ring_r = length(p * vec2(1.0, 1.7));
	for (int i = 0; i < 4; i++) {
		float age = beat + float(i);
		float radius = age * 0.42;
		float ring = exp(-pow((ring_r - radius) / (0.004 + 0.004 * age), 2.0));
		col += CREAM * ring * (1.0 - age / 4.0) * (0.22 + 0.25 * energy);
	}

	// Sound equaliser up both screen edges: columns of stacked cells.
	float side = min(uv.x, 1.0 - uv.x);     // distance in from the nearer edge
	float band = 0.16;
	if (side < band) {
		float columns = 7.0;
		float c = floor(side / band * columns);
		float cell_x = fract(side / band * columns);
		float seed = c + (uv.x < 0.5 ? 0.0 : 31.0);
		float now = hash(vec2(seed, beat_count));
		float before = hash(vec2(seed, beat_count - 1.0));
		float level = mix(before, now, smoothstep(0.0, 0.25, beat)) * (1.0 - c / columns * 0.6);
		level *= 0.35 + 0.45 * kick + 0.4 * energy;
		float height = 1.0 - uv.y;             // bars rise from the bottom
		float cells = 26.0;
		float cell_y = fract(height * cells);
		float lit = step(height, level) * step(0.18, cell_x) * step(cell_x, 0.82) * step(0.22, cell_y);
		vec3 bar = mix(CORAL, AMBER, smoothstep(0.0, 0.7, height));
		col += bar * lit * (0.22 + 0.2 * energy) * (1.0 - side / band * 0.5);
		// The tip of each bar is a brighter cap.
		col += CREAM * step(abs(height - level), 0.5 / cells) * step(0.18, cell_x) * step(cell_x, 0.82) * 0.25;
	}

	// Drifting sparkles: one per grid cell, rising slowly and twinkling.
	vec2 grid = vec2(aspect, 1.0) * 14.0;
	vec2 q = uv * grid + vec2(0.0, synk_time * 0.6);
	vec2 cell = floor(q);
	vec2 local = fract(q) - 0.5;
	float h = hash(cell);
	if (h > 0.72) {
		vec2 off = (vec2(hash(cell + 7.0), hash(cell + 13.0)) - 0.5) * 0.6;
		vec2 d = abs(local - off) * vec2(1.0, 1.0);
		float star = max(0.0, 1.0 - (sqrt(d.x * 9.0) + sqrt(d.y * 9.0)));
		float twinkle = 0.5 + 0.5 * sin(synk_time * (2.0 + h * 3.0) + h * 40.0);
		col += CREAM * star * star * twinkle * (0.35 + 0.35 * energy);
	}

	ALBEDO = col * brightness;
	ALPHA = 1.0;
}
