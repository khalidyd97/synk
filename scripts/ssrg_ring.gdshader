shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
// SSRG target ring on the judgement line: a grey double outline with a faint glass fill,
// always shown on the chart's lanes and turning white as a note arrives.
uniform float strength = 0.0;
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float d = length(p);
	float outer = exp(-pow((d - 0.88) / 0.045, 2.0));
	float inner = exp(-pow((d - 0.66) / 0.035, 2.0)) * 0.8;
	float fill = (1.0 - smoothstep(0.86, 0.9, d)) * 0.16;
	vec3 grey = vec3(0.55, 0.57, 0.62);
	ALBEDO = mix(grey, vec3(1.0), strength);
	ALPHA = clamp(outer + inner + fill, 0.0, 1.0) * mix(0.65, 1.0, strength);
}
