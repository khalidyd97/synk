shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

// Smoky see-through highway: densest in the distance, thinning toward the player so the
// stage behind glows through, then dissolving into the background at the far end.
uniform vec3 color : source_color = vec3(0.02, 0.02, 0.04);
uniform float opacity = 0.7;
// Opacity at the judgment end, as a fraction of opacity.
uniform float near_fraction = 0.72;
// World z where the track ends, and how far before it the fade begins.
uniform float far_end = -60.0;
uniform float fade_length = 24.0;

varying float world_z;

void vertex() {
	world_z = (MODEL_MATRIX * vec4(VERTEX, 1.0)).z;
}

void fragment() {
	ALBEDO = color;
	float near = mix(1.0, near_fraction, smoothstep(-30.0, 2.0, world_z));
	ALPHA = opacity * near * smoothstep(far_end, far_end + fade_length, world_z);
}
