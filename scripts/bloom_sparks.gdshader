shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;
// Rising sparkles for the "Bloom" hit effect, drawn on one camera-facing quad.
uniform vec4 tint : source_color = vec4(0.3, 0.85, 1.0, 1.0);
uniform float age = 0.0;
uniform float strength = 1.0;
uniform float seed = 0.0;
float h(float n) { return fract(sin(n * 91.7 + seed * 13.1) * 43758.5453); }
void fragment() {
	vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y);   // x -1..1, y 0 (bottom) .. 1 (top)
	float a = clamp(age, 0.0, 1.0);
	float glow = 0.0;
	for (int i = 0; i < 16; i++) {
		float fi = float(i);
		vec2 start = vec2((h(fi) * 2.0 - 1.0) * 0.75, h(fi + 3.0) * 0.12);
		vec2 pos = start + vec2((h(fi + 5.0) - 0.5) * 0.25 * a, (0.35 + h(fi + 9.0) * 0.6) * a);
		float size = mix(0.045, 0.02, a) * (0.6 + h(fi + 11.0));
		float dd = length((p - pos) * vec2(1.0, 1.6));
		glow += exp(-pow(dd / size, 2.0));
	}
	ALBEDO = mix(tint.rgb, vec3(1.0), 0.55);
	ALPHA = clamp(glow * 1.5 * (1.0 - a) * strength, 0.0, 1.0);
}
