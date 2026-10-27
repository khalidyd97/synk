shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

#include "res://scripts/highway_clip.gdshaderinc"
#include "res://scripts/ssrg_warp.gdshaderinc"

// A column of light running up the highway from wherever a finger is touching.
uniform vec3 tint : source_color = vec3(0.22, 0.73, 1.0);
uniform float intensity = 1.0;

varying float world_z;

void vertex() {
	rail_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	world_z = rail_position.z;
	if(ssrg_warp.x>0.5){
		float section=max(0.0,1.0+world_z/ssrg_warp.z);
		rail_position.x*=section;
		VERTEX=inverse(mat3(MODEL_MATRIX))*(rail_position-MODEL_MATRIX[3].xyz);
	}
}

void fragment() {
	if(ssrg_warp.x<0.5 && outside_rails(INV_VIEW_MATRIX[3].xyz)) discard;
	// A flat, sharp-edged column that fades toward the far end of the highway.
	float reach = ssrg_warp.x>0.5?smoothstep(0.0,1.0,1.0+world_z/ssrg_warp.z):smoothstep(-58.0,-6.0,world_z);
	ALBEDO = tint;
	ALPHA = 0.3 * reach * intensity;
}
