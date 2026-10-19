shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

// Soft contact shadow a raised rail casts onto the highway, darkest against the rail.
// UV.x 0 is the rail side; flip it for the right-hand rail.
uniform bool flip = false;
uniform float strength = 0.55;

varying float world_z;

void vertex() {
	world_z = (MODEL_MATRIX * vec4(VERTEX, 1.0)).z;
}

void fragment() {
	float across = flip ? 1.0 - UV.x : UV.x;
	ALBEDO = vec3(0.0);
	ALPHA = strength * pow(1.0 - across, 2.2) * smoothstep(-60.0, -38.0, world_z);
}
