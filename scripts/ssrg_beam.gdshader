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
// SYNK mode's beam. 0: the flat SSRG column. 1: a light column, a soft shaft with a bright
// thin core and fine rims, brightest at the finger. 2: a lane glow, light pooling on the
// road under the finger and fading up it, with no column.
uniform int synk_beam_style = 0;

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
	if(synk_beam_style>0){
		float across=abs(UV.x-0.5)*2.0;          // 0 down the middle of the lane, 1 at its edge
		float from_finger=1.0-UV.y;              // 0 at the finger, growing up the road
		if(synk_beam_style==1){
			float core=exp(-pow(across/0.12,2.0));
			float body=exp(-pow(across/0.5,2.0));
			float rims=exp(-pow((across-0.86)/0.045,2.0));
			float feather=1.0-smoothstep(0.8,1.0,across);
			// Hottest at the finger, easing off up the shaft.
			float heat=0.55+0.45*exp(-from_finger*5.0);
			float light=(body*0.40+core*0.85+rims*0.38)*feather*heat;
			ALBEDO=mix(tint,vec3(1.0,0.97,0.9),clamp(core*0.85+rims*0.3,0.0,1.0));
			ALPHA=clamp(light,0.0,1.0)*reach*intensity*release_alpha;
		}else{
			float spread=1.0-smoothstep(0.15,1.0,across);
			// Light lying on the road: strong under the finger, gone a short way up.
			float run=exp(-from_finger*3.2);
			float pool=exp(-pow(from_finger/0.11,2.0))*exp(-pow(across/0.7,2.0));
			float light=spread*run*0.46+pool*0.6;
			ALBEDO=mix(tint,vec3(1.0,0.95,0.85),clamp(pool*0.7,0.0,1.0));
			ALPHA=clamp(light,0.0,1.0)*intensity*release_alpha*smoothstep(0.0,0.15,reach);
		}
	}
}
