shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

#include "res://scripts/highway_clip.gdshaderinc"

// Hollow glowing ring lying on the highway where a hold or slide ends: "let go here".
// Shares the hold/miss uniforms with neon_asset.gdshader so clipping and graying still work.
uniform vec3 tint : source_color = vec3(0.64, 0.42, 1.0);
uniform float animation_time = 0.0;
uniform float desaturate = 0.0;
uniform float ghost_fade = 1.0;
uniform float clip_z = 1000.0;
uniform float motion = 0.0;
uniform float glow_pulse = 0.0;

varying float world_z;

void vertex() {
	rail_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	world_z = (MODEL_MATRIX * vec4(VERTEX, 1.0)).z;
}

void fragment() {
	if(outside_rails(INV_VIEW_MATRIX[3].xyz)) discard;
	if (world_z > clip_z) discard;
	float r = length(UV - 0.5) * 2.0;
	// A crisp bright band with a soft halo on both sides, and an empty middle.
	float band = exp(-pow((r - 0.72) / 0.07, 2.0));
	float halo = exp(-pow((r - 0.72) / 0.2, 2.0)) * 0.35;
	float pulse = 0.85 + 0.15 * sin(animation_time * 4.0);
	vec3 color = mix(tint, vec3(1.0), band * 0.45) * pulse;
	float gray = dot(color, vec3(0.299, 0.587, 0.114));
	ALBEDO = mix(color, vec3(gray * 0.5), desaturate);
	ALPHA = clamp(band + halo, 0.0, 1.0) * ghost_fade * smoothstep(-60.0, -40.0, world_z);
}
