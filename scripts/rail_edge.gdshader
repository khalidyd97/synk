shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

uniform vec3 tint : source_color = vec3(0.65, 0.4, 1.0);
uniform float animation_time = 0.0;
uniform float strength = 1.0;

// Fades toward the far end of the highway (world z -60), matching track_surface.gdshader.
varying float world_z;

void vertex() {
	world_z = (MODEL_MATRIX * vec4(VERTEX, 1.0)).z;
}

void fragment() {
	float travel = fract(UV.y * 3.0 + animation_time * 0.65);
	float runner = exp(-pow((travel - 0.5) * 12.0, 2.0));
	float heartbeat = 0.86 + 0.14 * sin(animation_time * 2.5);
	float core = 1.0 - smoothstep(0.12, 0.4, abs(UV.x - 0.5));
	ALBEDO = mix(tint, vec3(0.9, 0.94, 1.0), runner * 0.65);
	ALPHA = (0.22 + 0.53 * core + 0.55 * runner) * heartbeat * strength * smoothstep(-60.0, -36.0, world_z);
}
