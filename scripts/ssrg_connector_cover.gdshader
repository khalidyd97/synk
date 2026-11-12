shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
uniform sampler2D artwork : source_color, filter_linear_mipmap, repeat_disable;
global uniform vec4 ssrg_warp;
global uniform float ssrg_even;
float ssrg_depth(float z){float p=max(1.0+z/ssrg_warp.w,0.0);return ssrg_even>0.0?mix(ssrg_even,1.0,p):pow(p,ssrg_warp.y);}
float ssrg_scale(float z){return ssrg_depth(z);}
void vertex(){
    if(ssrg_warp.x>0.5){
        vec3 centre=MODEL_MATRIX[3].xyz;
        float q=ssrg_scale(centre.z);
        vec3 point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
        vec3 target=vec3(centre.x*q,centre.y,ssrg_warp.z*(ssrg_depth(centre.z)-1.0));
        VERTEX+=inverse(mat3(MODEL_MATRIX))*(target-centre+(point-centre)*(q-1.0));
    }
}
void fragment(){
    float alpha=texture(artwork,UV).a;
    ALBEDO=vec3(0.0);
    ALPHA=smoothstep(0.4,0.75,alpha);
}
