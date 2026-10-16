shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

// Highway surface that dissolves into the background toward the far end of the track.
uniform vec3 color : source_color = vec3(0.04, 0.06, 0.19);
uniform float opacity = 0.7;
// World z where the track ends, and how far before it the fade begins.
uniform float far_end = -60.0;
uniform float fade_length = 24.0;

varying float world_z;

void vertex() {
	world_z = (MODEL_MATRIX * vec4(VERTEX, 1.0)).z;
}

void fragment() {
	ALBEDO = color;
	ALPHA = opacity * smoothstep(far_end, far_end + fade_length, world_z);
}
