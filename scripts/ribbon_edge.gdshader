shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, fog_disabled;

#include "res://scripts/highway_clip.gdshaderinc"

// Thin bright edges along hold and slide trails. Shares clip_z with neon_asset.gdshader so a
// held trail disappears into the judgment bar, and fades/greys out with missed slides.
uniform vec3 color : source_color = vec3(0.8, 0.7, 1.0);
uniform float clip_z = 1000.0;
uniform float ghost_fade = 1.0;
uniform float desaturate = 0.0;

varying float world_z;
uniform bool projected_ribbon=false;
#include "res://scripts/ssrg_warp.gdshaderinc"

void vertex() {
	world_z=(MODEL_MATRIX*vec4(VERTEX,1.0)).z;
	VERTEX=projected_ribbon?ssrg_warp_section(VERTEX,VERTEX.z,MODEL_MATRIX):ssrg_warp_rigid(VERTEX,MODEL_MATRIX);
	rail_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}

void fragment() {
	if(outside_rails(INV_VIEW_MATRIX[3].xyz)) discard;
	if(ssrg_warp.x>0.5){if(rail_position.z>ssrg_warp_z(clip_z) || rail_position.z<ssrg_reveal_z())discard;}
	else if(world_z>clip_z)discard;
	float gray = dot(color, vec3(0.299, 0.587, 0.114));
	ALBEDO = mix(color, vec3(gray * 0.6), desaturate);
	ALPHA = ghost_fade * smoothstep(-60.0, -55.0, world_z);
}
