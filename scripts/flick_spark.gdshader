shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

// One spark streak for the flick hit splash, like the streaky shards of the Effect_A hit
// flash. The quad is turned along the spark's flight, so the streak runs from its bright
// head (UV.y = 0) to a fading tail (UV.y = 1), with a slight kink so it reads as a hot
// spark rather than a perfect line. A white core sits inside a cyan glow.
uniform vec3 tint : source_color = vec3(1.0);
uniform vec3 glow : source_color = vec3(0.30, 0.85, 1.0);
uniform float opacity = 1.0;
uniform float seed = 0.0;

float hash(float n) { return fract(sin(n * 127.1 + seed * 311.7) * 43758.5453); }

void fragment() {
	float y = UV.y;
	// A gentle bend: one kink part-way along, fixed for the spark's life.
	float kink = (hash(1.0) - 0.5) * 0.25 * sin(y * 3.14159);
	float d = abs(UV.x - 0.5 - kink);
	// Head brightest, tail fades out.
	float taper = smoothstep(0.0, 0.08, y) * pow(1.0 - y, 1.5);
	float core = exp(-d * 45.0) * taper;
	float halo = exp(-d * 12.0) * taper * 0.55;
	ALBEDO = mix(glow, tint, clamp(core * 1.5, 0.0, 1.0));
	ALPHA = clamp(core + halo, 0.0, 1.0) * opacity;
}
