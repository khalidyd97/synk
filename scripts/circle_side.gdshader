shader_type spatial;
render_mode unshaded, blend_mix, depth_prepass_alpha, cull_back, fog_disabled;

#include "res://scripts/highway_clip.gdshaderinc"

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
	rail_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	world_z = (MODEL_MATRIX * vec4(VERTEX, 1.0)).z;
	height = clamp(VERTEX.y / half_height * 0.5 + 0.5, 0.0, 1.0);
	front_facing = max(NORMAL.z, 0.0);
}

void fragment() {
	if(outside_rails(INV_VIEW_MATRIX[3].xyz)) discard;
	if (world_z > clip_z) discard;
	// Opaque continuous body: trails and lane guides cannot shine through its middle.
	vec3 pigment = recolor ? tint : vec3(0.12, 0.32, 1.0);
	vec3 deep = pigment * 0.24 + vec3(0.015, 0.018, 0.035);
	vec3 color = mix(deep, pigment * 0.70, smoothstep(0.0, 1.0, height));
	color *= 0.80 + 0.20 * front_facing;
	float top_lip = smoothstep(0.82, 0.98, height);
	color = mix(color, pigment * 0.95, top_lip * 0.48);
	// A dark lower bevel grounds the body without a second floating neon hoop.
	color *= mix(0.63, 1.0, smoothstep(0.0, 0.18, height));
	color *= 1.0 + glow_pulse * 0.25 * (0.5 + 0.5 * sin(animation_time * 3.0));
	float gray = dot(color, vec3(0.299, 0.587, 0.114));
	ALBEDO = mix(color, vec3(gray * 0.45), desaturate);
	ALPHA = ghost_fade * smoothstep(-60.0, -40.0, world_z);
}
