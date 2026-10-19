shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

#include "res://scripts/highway_clip.gdshaderinc"

// A column of light running up the highway from wherever a finger is touching.
uniform vec3 tint : source_color = vec3(0.22, 0.73, 1.0);
uniform float intensity = 1.0;

varying float world_z;

void vertex() {
	rail_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	world_z = (MODEL_MATRIX * vec4(VERTEX, 1.0)).z;
}

void fragment() {
	if(outside_rails(INV_VIEW_MATRIX[3].xyz)) discard;
	// A flat, sharp-edged column that fades toward the far end of the highway.
	float reach = smoothstep(-58.0, -6.0, world_z);
	ALBEDO = tint;
	ALPHA = 0.3 * reach * intensity;
}
