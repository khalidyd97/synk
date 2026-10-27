shader_type spatial;
render_mode unshaded, blend_mix, depth_prepass_alpha, cull_disabled, fog_disabled;
#include "res://scripts/highway_clip.gdshaderinc"
uniform vec3 tint : source_color=vec3(1.0,.73,.16);
uniform float clip_z=1000.0;
uniform float ghost_fade=1.0;
uniform float desaturate=0.0;
uniform bool joint=false;
uniform float ssrg_half_width=0.0;
varying float world_z;
#include "res://scripts/ssrg_warp.gdshaderinc"
void vertex(){
    // world_z stays the linear track position, so clip_z and the far fade are unchanged.
    world_z=(MODEL_MATRIX*vec4(VERTEX,1.0)).z;
    // Ribbons carry their centreline depth in UV2 (make_ribbon in highway_3d.gd).
    if(!joint && ssrg_warp.x>0.5 && length(CUSTOM0)>0.0){
        // Original RenderLongLine measures its normal AFTER projecting endpoints.
        vec2 a=vec2(CUSTOM0.x*ssrg_scale(MODEL_MATRIX[3].z+CUSTOM0.y),ssrg_warp_z(MODEL_MATRIX[3].z+CUSTOM0.y));
        vec2 b=vec2(CUSTOM0.z*ssrg_scale(MODEL_MATRIX[3].z+CUSTOM0.w),ssrg_warp_z(MODEL_MATRIX[3].z+CUSTOM0.w));
        vec2 delta=b-a;
        vec2 normal=length(delta)>0.00001?normalize(vec2(-delta.y,delta.x)):vec2(1.0,0.0);
        float section=MODEL_MATRIX[3].z+UV2.x;
        bool at_start=abs(UV2.x-CUSTOM0.y)<0.00001;
        vec2 point=(at_start?a:b)+normal*UV2.y*ssrg_half_width*ssrg_scale(section);
        vec3 target=vec3(point.x,(MODEL_MATRIX*vec4(VERTEX,1.0)).y,point.y);
        VERTEX=inverse(mat3(MODEL_MATRIX))*(target-MODEL_MATRIX[3].xyz);
    }else{
        VERTEX=joint?ssrg_warp_rigid(VERTEX,MODEL_MATRIX):ssrg_warp_section(VERTEX,UV2.x,MODEL_MATRIX);
    }
    rail_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}
void fragment(){
    if(outside_rails(INV_VIEW_MATRIX[3].xyz)) discard;
    if(ssrg_warp.x>0.5){
        // Clip on the drawn judgment plane, not interpolated obsolete timing Z.
        if(rail_position.z>ssrg_warp_z(clip_z)) discard;
        if(rail_position.z<ssrg_warp.z*(pow(0.5,ssrg_warp.y)-1.0)) discard;
    }else if(world_z>clip_z) discard;
    vec3 color=tint*.87;
    float opacity=.8;
    if(!joint){
        float edge=min(UV.x,1.0-UV.x);
        float feather=max(fwidth(UV.x),.001);
        opacity*=smoothstep(0.0,feather,edge);
    }
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
    ALPHA=opacity*ghost_fade*(ssrg_warp.x>0.5?1.0:smoothstep(-60.0,-55.0,world_z));
}
