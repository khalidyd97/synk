shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

// One lightning strand for the flick hit splash. The quad is tall and narrow and is turned
// along the strand's flight, so the jagged bolt runs from its tail (UV.y = 1) to its head
// (UV.y = 0). A white-hot core sits inside a cyan glow, matching the Effect_A hit flash and
// its streaky shards. The zig-zag re-rolls a few times a second so the strand crackles.
uniform vec3 tint : source_color = vec3(1.0);
uniform vec3 glow : source_color = vec3(0.30, 0.85, 1.0);
uniform float opacity = 1.0;
uniform float seed = 0.0;
// 0..1 through the strand's life; drives the crackle re-roll.
uniform float age = 0.0;

float hash(float n) { return fract(sin(n * 127.1 + seed * 311.7) * 43758.5453); }

// Centre line of the bolt at height y: straight segments between random kinks.
float bolt_x(float y, float roll, float kinks, float amp) {
	float s = y * kinks;
	float i = floor(s);
	float a = hash(i + roll * 13.0) - 0.5;
	float b = hash(i + 1.0 + roll * 13.0) - 0.5;
	// Ends stay on the axis so the strand reads as one connected bolt.
	float ends = smoothstep(0.0, 0.12, y) * smoothstep(1.0, 0.88, y);
	return mix(a, b, fract(s)) * amp * ends;
}

void fragment() {
	float roll = floor(age * 9.0);
	float y = UV.y;
	float x = UV.x - 0.5;
	float d = abs(x - bolt_x(y, roll, 7.0, 0.55));
	// A thinner side branch that forks off the upper half.
	float fork = abs(x - bolt_x(y, roll + 5.0, 5.0, 0.8) * 0.9 - 0.12 * (0.5 - y));
	float fork_mask = smoothstep(0.55, 0.15, y) * step(0.5, hash(roll + 31.0));

	// Bright at the head, thinning toward the tail.
	float taper = mix(1.0, 0.35, y) * smoothstep(0.0, 0.05, y) * smoothstep(1.0, 0.9, y);
	float core = exp(-d * 60.0) * taper;
	float halo = exp(-d * 14.0) * taper * 0.65;
	float branch = (exp(-fork * 80.0) + exp(-fork * 20.0) * 0.35) * taper * fork_mask * 0.7;

	ALBEDO = mix(glow, tint, clamp(core * 1.4, 0.0, 1.0));
	ALPHA = clamp(core + halo + branch, 0.0, 1.0) * opacity;
}
