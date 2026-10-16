shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

// The puck's deep cobalt wall, cyan upper lip and thin luminous lower rim.
// The default blue note follows the reference; other types take the song palette.
uniform vec3 tint : source_color = vec3(0.22, 0.73, 1.0);
uniform float half_height = 0.17;
uniform bool recolor = true;
uniform float animation_time = 0.0;
uniform float glow_pulse = 0.0;
uniform float desaturate = 0.0;
uniform float ghost_fade = 1.0;
uniform float clip_z = 1000.0;

varying float world_z;
varying float height;
varying float front_facing;

void vertex() {
	world_z = (MODEL_MATRIX * vec4(VERTEX, 1.0)).z;
	height = clamp(VERTEX.y / half_height * 0.5 + 0.5, 0.0, 1.0);
	front_facing = max(NORMAL.z, 0.0);
}

void fragment() {
	if (world_z > clip_z) discard;
	vec3 deep = recolor ? tint * 0.19 : vec3(0.005, 0.025, 0.38);
	vec3 color = mix(deep, tint * 1.08, smoothstep(0.13, 0.79, height));
	color *= 0.73 + 0.27 * front_facing;
	float top_lip = exp(-pow((height - 0.965) / 0.045, 2.0));
	float lower_lip = exp(-pow((height - 0.075) / 0.032, 2.0));
	float groove = exp(-pow((height - 0.23) / 0.022, 2.0));
	color *= 1.0 - groove * 0.24;
	color = mix(color, tint * 1.7, lower_lip * 0.92);
	color = mix(color, vec3(1.0), top_lip * 0.88);
	color *= 1.0 + glow_pulse * (0.5 + 0.5 * sin(animation_time * 3.0));
	float gray = dot(color, vec3(0.299, 0.587, 0.114));
	ALBEDO = mix(color, vec3(gray * 0.45), desaturate);
	ALPHA = 0.97 * ghost_fade * smoothstep(-60.0, -40.0, world_z);
}
