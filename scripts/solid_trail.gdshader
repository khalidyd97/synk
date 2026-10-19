shader_type spatial;
render_mode unshaded, blend_mix, depth_prepass_alpha, cull_disabled, fog_disabled;
#include "res://scripts/highway_clip.gdshaderinc"
uniform vec3 tint : source_color=vec3(1.0,.73,.16);
uniform float clip_z=1000.0;
uniform float ghost_fade=1.0;
uniform float desaturate=0.0;
uniform bool joint=false;
varying float world_z;
void vertex(){
    rail_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    world_z=rail_position.z;
}
void fragment(){
    if(outside_rails(INV_VIEW_MATRIX[3].xyz) || world_z>clip_z) discard;
    vec3 color=tint*.87;
    float opacity=.8;
    if(joint){
        float radius=length(UV-.5)*2.0;
        if(radius>1.0) discard;
        float center=1.0-smoothstep(.14,.64,radius);
        float rim=exp(-pow((radius-.80)*22.0,2.0));
        color=mix(tint,vec3(.98),center*.9)+tint*rim*.15;
        opacity=1.0-smoothstep(.94,1.0,radius);
    }
    float gray=dot(color,vec3(.299,.587,.114));
    ALBEDO=mix(color,vec3(gray*.6),desaturate);
    ALPHA=opacity*ghost_fade*smoothstep(-60.0,-40.0,world_z);
}
