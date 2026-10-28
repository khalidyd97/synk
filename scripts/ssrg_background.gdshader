shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;
uniform sampler2D artwork : source_color, filter_linear;
void vertex() {
    // One reusable quad; retain the source's tapered near/far edges exactly.
    vec2 center = INSTANCE_CUSTOM.xy * (1.0 - UV.x);
    float half_width = mix(INSTANCE_CUSTOM.w, INSTANCE_CUSTOM.z, UV.x);
    VERTEX = vec3(center + vec2(0.0, (1.0 - 2.0 * UV.y) * half_width), 0.0);
}
void fragment() {
	vec4 art = texture(artwork, UV);
	ALBEDO = art.rgb * COLOR.rgb;
	ALPHA = art.a * COLOR.a;
}
