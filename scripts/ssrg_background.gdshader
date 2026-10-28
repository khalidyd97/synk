shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;
uniform sampler2D artwork : source_color, filter_linear;
void fragment() {
	vec4 art = texture(artwork, UV);
	ALBEDO = art.rgb * COLOR.rgb;
	ALPHA = art.a * COLOR.a;
}
