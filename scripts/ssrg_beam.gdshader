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
// SYNK mode's beam: a lane glow. Amber light pools on the road at the judgment line under
// the finger and fades away up the road and out to the sides, with no hard edge anywhere.
uniform bool synk_glow = false;
// How far up the beam's quad the judgment line sits, from its near end (0..1).
uniform float glow_line = 0.142;

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
	// Strong coloured lane light, matching the supplied SMTOWN gameplay.
	// Keep alpha blending so the light remains coloured beneath bright notes.
	ALPHA = 0.62 * reach * intensity * release_alpha;
	if(synk_glow){
		float across=abs(UV.x-0.5)*2.0;          // 0 down the middle of the lane, 1 at its edge
		float from_line=(1.0-UV.y)-glow_line;    // 0 at the judgment line, growing up the road
		// Sideways: a soft bell that has melted away well before the quad's edge.
		float spread=exp(-pow(across/0.42,2.0))*(1.0-smoothstep(0.55,0.95,across));
		// Up the road: strongest at the line, a long gentle tail beyond it; a short, soft
		// fall-off toward the player so the near end never shows as a cut.
		float run=from_line>=0.0?exp(-from_line*3.4):exp(-pow(from_line/0.07,2.0));
		// The pool of light at the line itself, round and soft.
		float pool=exp(-pow(from_line/0.10,2.0))*exp(-pow(across/0.5,2.0));
		float light=spread*run*0.42+pool*0.5;
		ALBEDO=mix(tint,vec3(1.0,0.95,0.85),clamp(pool*0.6,0.0,1.0));
		ALPHA=clamp(light,0.0,1.0)*intensity*release_alpha*smoothstep(0.0,0.2,reach);
	}
}
