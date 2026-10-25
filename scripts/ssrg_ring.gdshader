shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
// Target ring on the judgement line: a white double outline that brightens as a note arrives.
uniform float strength = 0.0;
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float d = length(p);
	float outer = exp(-pow((d - 0.86) / 0.05, 2.0));
	float inner = exp(-pow((d - 0.70) / 0.035, 2.0)) * 0.6;
	float glow = exp(-pow((d - 0.80) / 0.2, 2.0)) * 0.25;
	ALBEDO = vec3(0.92, 0.96, 1.0);
	ALPHA = clamp((outer + inner + glow) * strength, 0.0, 1.0);
}
