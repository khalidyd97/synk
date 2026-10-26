shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
// SSRG lane laser: a beam of light up the lane from the judgement line, brightest at the line
// and fading toward the far end, soft at both sides. Lies on the floor, so it follows the
// track's perspective. UV.y is 1 at the judgement line (near end) and 0 at the far end.
uniform vec3 color : source_color = vec3(0.35, 0.85, 1.0);
uniform float strength = 1.0;
void fragment() {
	float across = abs(UV.x - 0.5) * 2.0;
	float body = 1.0 - smoothstep(0.35, 1.0, across);
	float core = exp(-across * across * 9.0);
	float along = pow(UV.y, 1.8);
	vec3 light = color * (0.55 * body + 0.6 * core) + vec3(1.0) * core * core * 0.35;
	ALBEDO = light;
	ALPHA = clamp(along * strength * (0.6 * body + 0.5 * core), 0.0, 1.0);
}
