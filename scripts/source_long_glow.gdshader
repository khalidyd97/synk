shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;
uniform vec3 tint : source_color=vec3(1.0,.72,.18);
uniform float clip_z=1000.0;
uniform float ghost_fade=1.0;
uniform vec4 source_tint : source_color=vec4(1.0);
varying float world_z;
#include "res://scripts/ssrg_warp.gdshaderinc"
void vertex(){
    world_z=(MODEL_MATRIX*vec4(VERTEX,1.0)).z;
    VERTEX=ssrg_warp_rigid(VERTEX,MODEL_MATRIX);
}
void fragment(){
    if(world_z>clip_z)discard;
    float radius=length((UV-.5)*2.0);
    float glow=pow(max(0.0,1.0-radius),2.2);
    ALBEDO=tint*source_tint.rgb;
    ALPHA=glow*.34*ghost_fade*source_tint.a;
}
