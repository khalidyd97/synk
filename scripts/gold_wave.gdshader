shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;
// Combo multiplier wave: a soft gold band with a bright leading edge (UV.y = 0) and a
// trail that fades behind it, plus a faint shimmer across the lanes.
uniform vec4 color : source_color = vec4(1.0, 0.82, 0.34, 1.0);
uniform float strength = 1.0;
uniform float edge_only = 0.0;   // 1 for the judgement-bar glow: soft on both sides
void fragment() {
	float y = UV.y;
	float glow;
	if (edge_only > 0.5) {
		glow = pow(1.0 - abs(y - 0.5) * 2.0, 1.5);
	} else {
		float edge = exp(-pow(y * 9.0, 2.0)) * 1.6;
		float trail = pow(1.0 - y, 1.6) * 0.85;
		glow = edge + trail;
	}
	float shimmer = 0.94 + 0.06 * sin(UV.x * 18.0 + TIME * 6.0);
	float sides = smoothstep(0.0, 0.06, UV.x) * smoothstep(0.0, 0.06, 1.0 - UV.x);
	ALBEDO = mix(color.rgb, vec3(1.0, 0.97, 0.85), clamp(glow - 0.9, 0.0, 1.0));
	ALPHA = clamp(glow * shimmer * sides * strength, 0.0, 1.0);
}
