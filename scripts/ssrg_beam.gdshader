shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

#include "res://scripts/highway_clip.gdshaderinc"
#include "res://scripts/ssrg_warp.gdshaderinc"

// A column of light running up the highway from wherever a finger is touching.
uniform vec3 tint : source_color = vec3(0.22, 0.73, 1.0);
uniform float intensity = 1.0;
uniform float release_alpha = 1.0;
uniform float ssrg_beam_reach=9.90234375;
uniform sampler2D ssrg_beam_art : filter_linear, repeat_disable;

varying float world_z;

void vertex() {
	rail_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	world_z = rail_position.z;
	if(ssrg_warp.x>0.5){
		float section=max(0.0,1.0+world_z/ssrg_beam_reach);
		rail_position.x*=section;
		VERTEX=inverse(mat3(MODEL_MATRIX))*(rail_position-MODEL_MATRIX[3].xyz);
	}
}

void fragment() {
	if(ssrg_warp.x<0.5 && outside_rails(INV_VIEW_MATRIX[3].xyz)) discard;
	// A flat, sharp-edged column that fades toward the far end of the highway.
	float reach = ssrg_warp.x>0.5?texture(ssrg_beam_art,UV).a:smoothstep(-58.0,-6.0,world_z);
	ALBEDO = tint;
	ALPHA = 0.3 * reach * intensity * release_alpha;
}
