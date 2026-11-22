shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
uniform vec3 tint : source_color = vec3(0.2,0.12,0.28);
uniform float opacity = 0.2;
varying float world_z;
#include "res://scripts/ssrg_warp.gdshaderinc"
void vertex(){
    vec3 raw_vertex=VERTEX;
    VERTEX=ssrg_warp_canvas(VERTEX,MODEL_MATRIX);
    world_z=(MODEL_MATRIX*vec4(raw_vertex,1.0)).z;
}
void fragment(){
    float side_feather=smoothstep(0.0,0.015,UV.x)*smoothstep(0.0,0.015,1.0-UV.x);
    ALBEDO=tint;
    ALPHA=opacity*side_feather*smoothstep(-60.0,-36.0,world_z)*ssrg_reveal(world_z);
}
