shader_type canvas_item;

// A dark concert stage seen through a lens, built from physically inspired layers:
//   haze      - drifting smoke, the medium that makes light visible
//   beams     - moving-head spotlights, visible only where they cross haze
//   bokeh     - out-of-focus lights: soft discs with a brighter rim and slight colour fringe
//   dust      - specks that glint only inside beams
//   lens      - vignette, gentle bloom lift, film grain
// Every motion uses whole cycles of `phase` (0..1), so frame 0 follows the last frame exactly.

uniform float phase = 0.0;

// Sine-free hash: stable on mobile/low-precision GPUs (no blocky artefacts).
float hash(vec2 p) {
	p = fract(p * vec2(443.897, 441.423));
	p += dot(p, p.yx + 19.19);
	return fract((p.x + p.y) * p.x);
}
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
// Looping fbm: the sample point travels round a circle once per loop.
float fbm(vec2 p, float speed) {
	vec2 drift = vec2(cos(TAU * phase), sin(TAU * phase)) * speed;
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 5; i++) { v += a * noise(p + drift); p = p * 2.03 + vec2(1.7, 9.2); drift *= 1.4; a *= 0.5; }
	return v;
}

vec3 beam(vec2 uv, vec2 origin, float angle, float spread, vec3 color, float haze) {
	vec2 dir = vec2(sin(angle), cos(angle));
	vec2 d = uv - origin;
	float along = dot(d, dir);
	if (along <= 0.0) return vec3(0.0);
	float across = abs(d.x * dir.y - d.y * dir.x);
	float width = 0.012 + along * spread;
	float core = exp(-pow(across / width, 2.0) * 2.0) + exp(-pow(across / (width * 0.25), 2.0)) * 0.6;
	float falloff = exp(-along * 0.75);
	// Visible only through haze; a hot spot at the fixture lens.
	float body = core * falloff * (0.08 + 1.9 * haze * haze);
	float lens = exp(-dot(d, d) * 900.0) * 1.6;
	return color * (body + lens);
}

void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	float aspect = res.x / res.y;
	vec2 uv = vec2(UV.x * aspect, UV.y);
	float t = TAU * phase;

	// Deep stage black, slightly cooler at the top, warmer near the floor glow.
	vec3 col = mix(vec3(0.010, 0.012, 0.030), vec3(0.030, 0.012, 0.040), smoothstep(0.2, 1.0, UV.y));

	// Haze: two layers drifting at different speeds and scales.
	float haze = fbm(uv * vec2(1.6, 2.4) + vec2(0.0, 0.0), 0.9) * 0.65 + fbm(uv * 4.0 + 3.1, 1.6) * 0.35;
	haze = smoothstep(0.28, 0.80, haze);
	col += vec3(0.035, 0.030, 0.060) * haze;

	// Moving heads on a truss just above frame: each sways a whole number of times per loop.
	vec3 cyan = vec3(0.20, 0.75, 1.00);
	vec3 magenta = vec3(1.00, 0.25, 0.80);
	vec3 violet = vec3(0.55, 0.35, 1.00);
	vec3 warm = vec3(1.00, 0.82, 0.62);
	vec3 light = vec3(0.0);
	light += beam(uv, vec2(0.18 * aspect, -0.06), 0.45 + 0.22 * sin(t + 0.3), 0.10, cyan, haze) * 0.55;
	light += beam(uv, vec2(0.34 * aspect, -0.06), 0.15 + 0.28 * sin(t * 2.0 + 1.9), 0.08, violet, haze) * 0.50;
	light += beam(uv, vec2(0.50 * aspect, -0.08), 0.00 + 0.18 * sin(t + 3.1), 0.06, warm, haze) * 0.38;
	light += beam(uv, vec2(0.66 * aspect, -0.06), -0.15 + 0.28 * sin(t * 2.0 + 4.4), 0.08, violet, haze) * 0.50;
	light += beam(uv, vec2(0.82 * aspect, -0.06), -0.45 + 0.22 * sin(t + 2.2), 0.10, magenta, haze) * 0.55;
	col += light;

	// Bokeh: out-of-focus stage lights and LEDs behind the beams.
	vec3 bokeh = vec3(0.0);
	for (int i = 0; i < 26; i++) {
		float fi = float(i);
		vec2 base = vec2((0.04 + hash(vec2(fi, 1.3)) * 0.92) * aspect, 0.35 + hash(vec2(fi, 7.1)) * 0.60);
		float k = floor(1.0 + hash(vec2(fi, 3.3)) * 2.0);
		vec2 c = base + vec2(cos(t * k + fi), sin(t * k + fi * 1.7)) * 0.012;
		float r = 0.012 + pow(hash(vec2(fi, 9.9)), 2.0) * 0.07;
		float side = hash(vec2(fi, 4.4));
		vec3 tint = side < 0.4 ? cyan : (side < 0.75 ? magenta : (side < 0.9 ? violet : warm));
		float twinkle = 0.55 + 0.45 * sin(t * floor(1.0 + hash(vec2(fi, 5.5)) * 3.0) + fi * 2.3);
		float dist = length(uv - c);
		// Slightly different radius per colour channel gives the lens fringe.
		vec3 disc;
		for (int ch = 0; ch < 3; ch++) {
			float rr = r * (1.0 + (float(ch) - 1.0) * 0.035);
			float inside = 1.0 - smoothstep(rr * 0.80, rr, dist);
			float rim = smoothstep(rr * 0.55, rr * 0.92, dist) * inside;
			disc[ch] = inside * 0.75 + rim * 0.25;
		}
		// Small lights are brighter and more saturated; big discs are faint, as with a real lens.
		float energy = mix(0.30, 0.06, smoothstep(0.012, 0.08, r));
		bokeh += disc * tint * twinkle * energy * (0.6 + 0.4 * hash(vec2(fi, 2.2)));
	}
	col += bokeh * (0.7 + 0.3 * smoothstep(0.0, 0.6, UV.y));

	// Dust: tiny specks, visible only where a beam passes.
	vec2 cell = uv * vec2(140.0, 120.0) + vec2(cos(t), sin(t)) * 3.0 + vec2(0.0, -t * 0.0);
	float speck = step(0.992, hash(floor(cell))) * (1.0 - smoothstep(0.0, 0.35, length(fract(cell) - 0.5)));
	col += speck * dot(light, vec3(0.33)) * 1.6;

	// Floor glow and a soft reflection band at the bottom.
	col += mix(cyan, magenta, UV.x) * smoothstep(0.78, 1.0, UV.y) * 0.08 * (0.6 + 0.4 * haze);

	// Lens: gentle highlight roll-off (filmic), vignette, grain.
	col *= 1.3;
	col = col / (1.0 + col * 0.55);
	float vignette = smoothstep(1.25, 0.35, length((UV - vec2(0.5, 0.45)) * vec2(1.1, 1.4)));
	col *= mix(0.45, 1.0, vignette);
	float grain = hash(UV * res + vec2(floor(phase * 300.0) * 13.0, 0.0)) - 0.5;
	col += grain * 0.018;
	COLOR = vec4(max(col, vec3(0.0)), 1.0);
}
