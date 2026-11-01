shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;
uniform sampler2D artwork : source_color, filter_linear;
// SMTOWN-style light trails: keep both ends fine instead of letting the
// source's depth-derived trailing width grow into a broad opaque wedge.
uniform float streak_half_width = 1.6;
uniform float streak_width_scale = 0.6;
void vertex() {
    // Reuse the batched trajectories and colour profiles, with a thin silhouette.
    vec2 center = INSTANCE_CUSTOM.xy * (1.0 - UV.x);
    float far_width = min(INSTANCE_CUSTOM.w * streak_width_scale, streak_half_width);
    float near_width = min(INSTANCE_CUSTOM.z * streak_width_scale, streak_half_width);
    float half_width = mix(far_width, near_width, UV.x);
    VERTEX = vec3(center + vec2(0.0, (1.0 - 2.0 * UV.y) * half_width), 0.0);
}
void fragment() {
	vec4 art = texture(artwork, UV);
	ALBEDO = art.rgb * COLOR.rgb;
	// Feather the ends and edges so overlapping trails remain light rather
	// than drawing hard bars over the background photo.
	float edge = smoothstep(0.0, 0.2, UV.y) * smoothstep(0.0, 0.2, 1.0 - UV.y);
	float ends = smoothstep(0.0, 0.035, UV.x) * smoothstep(0.0, 0.08, 1.0 - UV.x);
	ALPHA = art.a * COLOR.a * edge * ends;
}
