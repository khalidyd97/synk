shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

// One spark streak for the flick hit splash, like the streaky shards of the Effect_A hit
// flash. The quad is turned along the spark's flight, so the streak runs from its bright
// head (UV.y = 0) to a fading tail (UV.y = 1), with a slight kink so it reads as a hot
// spark rather than a perfect line. A white core sits inside a cyan glow.
uniform vec3 tint : source_color = vec3(1.0);
uniform vec3 glow : source_color = vec3(0.30, 0.85, 1.0);
// The colour the glow cools to over the spark's life, like the hit flash's fading frames.
uniform vec3 deep : source_color = vec3(0.18, 0.45, 1.0);
// 0 at launch, 1 when the spark dies.
uniform float age = 0.0;
uniform float opacity = 1.0;
uniform float seed = 0.0;
// 0 for a perfectly straight streak (the upward flare), 1 for a spark's slight bend.
uniform float bend = 1.0;
// Core width: higher is thinner.
uniform float sharpness = 45.0;

float hash(float n) { return fract(sin(n * 127.1 + seed * 311.7) * 43758.5453); }

void fragment() {
	float y = UV.y;
	// A gentle bend: one kink part-way along, fixed for the spark's life.
	float kink = (hash(1.0) - 0.5) * 0.25 * sin(y * 3.14159) * bend;
	float d = abs(UV.x - 0.5 - kink);
	// Head brightest, tail fades out.
	float taper = smoothstep(0.0, 0.08, y) * pow(1.0 - y, 1.5);
	float core = exp(-d * sharpness) * taper;
	float halo = exp(-d * sharpness * 0.27) * taper * 0.7;
	// White-hot core early on, cooling from cyan to deep blue, like the hit flash.
	vec3 halo_color = mix(glow, deep, smoothstep(0.2, 0.9, age));
	ALBEDO = mix(halo_color, tint, clamp(core * 1.5 * (1.0 - 0.7 * age), 0.0, 1.0));
	// Fade the glow to nothing before the quad's sides, so no box edge shows.
	float sides = smoothstep(0.5, 0.25, abs(UV.x - 0.5));
	ALPHA = clamp(core + halo, 0.0, 1.0) * sides * opacity;
}
