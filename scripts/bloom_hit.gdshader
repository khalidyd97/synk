shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;
// "Bloom" hit effect, lying flat on the judgement line: an overexposed white core inside a
// coloured halo, plus two thin white rings racing outward. age runs 0 -> 1 over the hit.
uniform vec4 tint : source_color = vec4(0.3, 0.85, 1.0, 1.0);
uniform float age = 0.0;
uniform float strength = 1.0;
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;          // mesh is wide, so this is an ellipse on screen
	float d = length(p);
	float a = clamp(age, 0.0, 1.0);
	float pop = smoothstep(0.0, 0.08, a);                     // very fast attack
	float fade = pow(1.0 - a, 1.6);
	float core = exp(-d * d * mix(6.0, 2.4, a)) * 2.2;        // white-hot centre that spreads
	float halo = exp(-d * d * 1.5) * 1.5;                     // wide coloured glow
	float r1 = mix(0.22, 0.95, sqrt(a));
	float r2 = mix(0.12, 0.72, sqrt(a));
	float rings = exp(-pow((d - r1) / 0.035, 2.0)) + 0.8 * exp(-pow((d - r2) / 0.03, 2.0));
	vec3 col = tint.rgb * halo * 1.4 + vec3(1.0) * (core + rings);
	float edge = 1.0 - smoothstep(0.85, 1.0, d);
	ALBEDO = col;
	ALPHA = clamp((halo + core + rings) * pop * fade * edge * strength, 0.0, 1.0);
}
