shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
uniform sampler2D artwork : source_color, filter_linear_mipmap, repeat_disable;
uniform bool along_rail = true;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec3 floor_tint : source_color = vec3(0.0);
uniform float floor_opacity = 1.0;
uniform float rail_entrance : hint_range(0.0,1.0) = 1.0;
uniform float floor_entrance : hint_range(0.0,1.0) = 1.0;
uniform float rail_side = 1.0;
// A second copy of the rail drawn above the judgment bar: the rail's light only, no road.
uniform bool rail_only = false;
// The recorder: 1 keeps only the rail's bright line and drops the glow around it.
uniform float calm = 0.0;
uniform vec3 tone = vec3(0.0, 1.0, 1.0);   // SYNK mode adaptive colours
#include "res://scripts/synk_tone.gdshaderinc"
#include "res://scripts/ssrg_warp.gdshaderinc"
// Bending road: the stage node itself sits at the judgment line's shift; the picture is slid
// sideways by the rest, more or less at each height. Width of the quad in world units.
const float STAGE_QUAD_WIDTH = 720.0*9.75/512.0;
varying float canvas_q;
void vertex(){
    canvas_q=1.0+(MODEL_MATRIX*vec4(VERTEX,1.0)).z/ssrg_warp.z;
    // Each half arrives gently from its outer edge while its rail is being drawn.
    VERTEX.x+=rail_side*(1.0-rail_entrance)*.72;
}
void fragment(){
    vec2 uv=along_rail ? vec2(1.0-UV.y,UV.x) : UV;
    if(!along_rail && ssrg_bend.x!=0.0) uv.x+=rail_side*(ssrg_bend_at(canvas_q)-ssrg_bend_at(1.0))/STAGE_QUAD_WIDTH;
    vec4 art=texture(artwork,uv);
    // Slid past the picture's outer edge there is nothing; past its inner edge, more road.
    if(uv.x<0.0) art.a=0.0;
    vec3 painted=art.rgb;
    art.rgb=synk_turn(art.rgb,tone);
    bool road=max(art.r,max(art.g,art.b))<0.05;
    // Draw the rail down its length instead of fading the complete silhouette at once.
    float rail_wipe=1.0-smoothstep(rail_entrance,rail_entrance+.075,UV.y);
    float leading_edge=exp(-pow((UV.y-rail_entrance)*24.0,2.0))
        *smoothstep(0.0,.08,rail_entrance)*(1.0-smoothstep(.88,1.0,rail_entrance));
    ALBEDO=road?floor_tint:art.rgb*tint.rgb*(1.0+leading_edge*1.65);
    EMISSION=road?vec3(0.0):art.rgb*tint.rgb*leading_edge*.85;
    ALPHA=art.a*tint.a*(road?floor_opacity*floor_entrance:rail_wipe*smoothstep(0.0,.16,rail_entrance));
    if(rail_only){
        // Only the light itself: the rail's dim outer glow must not darken the bar under it.
        float light=max(art.r,max(art.g,art.b));
        ALBEDO=art.rgb/max(light,0.001)*tint.rgb*(1.0+leading_edge*1.65);
        // Fade the faintest glow out smoothly, so it leaves no edge across the bar.
        ALPHA=art.a*tint.a*rail_wipe*smoothstep(0.0,.16,rail_entrance)*light*smoothstep(0.02,0.22,light);
    }
    if(calm>0.0 && !road){
        // The glow is coloured and the line itself is near white, so keep what is white.
        float white=min(painted.r,min(painted.g,painted.b));
        ALPHA*=mix(1.0,smoothstep(0.18,0.7,white),calm);
    }
}
