shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

// SYNK mode's flick hit: the note's chevrons released upward. Three chevrons leave the hit
// one after another, climb a soft plume of light and thin away, with a few embers carried
// up beside them. One quad standing on the judgment bar (UV.y = 1 at the hit).
uniform vec3 glow : source_color = vec3(1.0, 0.24, 0.55);
// 0 at the hit, 1 when it has gone.
uniform float age = 0.0;
uniform float opacity = 1.0;
// The quad's height over its width.
uniform float aspect = 3.0;
uniform float seed = 0.0;

float hash(float n) { return fract(sin(n * 127.1 + seed * 311.7) * 43758.5453); }

void fragment() {
	// x: -1..1 across. y: height above the hit, in half-widths. top: the quad's full height.
	float x = (UV.x - 0.5) * 2.0;
	float top = aspect * 2.0;
	float y = (1.0 - UV.y) * top;
	float gone = 1.0 - age;
	float rise = 1.0 - pow(gone, 3.0);
	float reach = top * (0.22 + 0.74 * rise);
	float light = 0.0;
	float hot = 0.0;
	// The plume: a soft column, narrowing as it climbs, reaching higher as the chevrons go.
	float column = exp(-pow(x / (0.34 * (1.0 - 0.55 * y / top)), 2.0));
	light += column * smoothstep(reach, reach * 0.15, y) * pow(gone, 1.5) * 0.5;
	// A fine bright spine through it.
	light += exp(-pow(x / 0.03, 2.0)) * smoothstep(reach, reach * 0.4, y) * gone * gone * 0.8;
	// The chevrons, each leaving a little after the one before and stopping a little lower.
	for (int i = 0; i < 3; i++) {
		float wait = float(i) * 0.13;
		float k = clamp((age - wait) / (1.0 - wait), 0.0, 1.0);
		if (k <= 0.0) continue;
		float e = 1.0 - pow(1.0 - k, 2.6);
		float at = top * (0.10 + (0.78 - 0.19 * float(i)) * e);
		float span = 0.66 * (1.0 - 0.30 * e) * (1.0 - 0.10 * float(i));
		float d = abs(y - at + abs(x) * 0.8);
		float width = 0.075 * (1.0 - 0.55 * k) + 0.014;
		float arm = 1.0 - smoothstep(span * 0.7, span, abs(x));
		float fade = pow(1.0 - k, 1.25) * smoothstep(0.0, 0.08, k);
		float line = exp(-pow(d / width, 2.0)) * arm * fade;
		light += line * (1.0 - 0.14 * float(i)) + exp(-d / (width * 4.5)) * arm * fade * 0.22;
		hot += line;
	}
	// Embers carried up beside the chevrons.
	for (int j = 0; j < 7; j++) {
		float f = float(j);
		vec2 at = vec2((hash(f) - 0.5) * (1.1 - 0.5 * rise), top * (0.06 + hash(f + 10.0) * 0.12 + rise * (0.30 + 0.55 * hash(f + 20.0))));
		at.x += sin(age * 6.0 + f) * 0.05;
		float size = 0.028 + 0.03 * hash(f + 30.0);
		float ember = exp(-dot(vec2(x, y) - at, vec2(x, y) - at) / (size * size));
		light += ember * gone * smoothstep(0.0, 0.1, age);
		hot += ember * 0.6 * gone;
	}
	// No box: fade out before every edge of the quad, and rise out of the flash below.
	light *= smoothstep(1.0, 0.72, abs(x)) * smoothstep(top, top * 0.86, y) * smoothstep(0.0, 0.22, y);
	ALBEDO = mix(glow, vec3(1.0), clamp(hot * 0.85, 0.0, 1.0) * 0.8);
	ALPHA = clamp(light, 0.0, 1.0) * opacity;
}
