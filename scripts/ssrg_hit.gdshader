shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;
// SSRG hit effect: plays one frame of an 11-frame sheet (4 x 3 grid, black background, added).
uniform sampler2D atlas : source_color, filter_linear, repeat_disable;
uniform float frame = 0.0;
uniform float strength = 1.0;
void fragment() {
	float f = clamp(floor(frame), 0.0, 10.0);
	vec2 cell = vec2(mod(f, 4.0), floor(f / 4.0));
	vec2 uv = (cell + UV) / vec2(4.0, 3.0);
	vec3 c = texture(atlas, uv).rgb * strength;
	ALBEDO = c;
	ALPHA = clamp(max(c.r, max(c.g, c.b)), 0.0, 1.0);
}
