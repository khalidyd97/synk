shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;
// Rail notes (prototype): notes that ride on the two rails beside the road.
// shape 0: the note itself, a short bright bar. 1: the body of a rail hold, a strip along the
// rail. 2: the mark on the judgment line that shows where to touch.
uniform int shape = 0;
uniform vec4 color : source_color = vec4(.62,.91,1.0,1.0);
uniform float strength = 1.0;
#include "res://scripts/ssrg_warp.gdshaderinc"
varying float shown;
void vertex(){
    if(shape==1){
        shown=ssrg_reveal((MODEL_MATRIX*vec4(VERTEX,1.0)).z);
        VERTEX=ssrg_warp_canvas(VERTEX,MODEL_MATRIX);
    }else{
        shown=ssrg_reveal(MODEL_MATRIX[3].z);
        VERTEX=ssrg_warp_rigid(VERTEX,MODEL_MATRIX);
    }
}
float rounded_box(vec2 p, vec2 half_size, float radius){
    vec2 d=abs(p)-half_size+radius;
    return length(max(d,0.0))+min(max(d.x,d.y),0.0)-radius;
}
void fragment(){
    float light=0.0;
    if(shape==1){
        float across=abs(UV.x-.5)*2.0;
        light=.4*(1.0-smoothstep(.72,.8,across))+.8*exp(-pow((across-.74)/.07,2.0));
    }else{
        // The quad is 3 wide for every 1 tall; the bar sits in its middle with room for glow.
        vec2 p=(UV-.5)*vec2(3.0,1.0);
        float d=rounded_box(p,vec2(1.05,.2),.2);
        if(shape==0) light=(1.0-smoothstep(-.03,.02,d))+.55*exp(-max(d,0.0)*9.0);
        else light=exp(-pow(d/.035,2.0))*.9+.18*exp(-max(d,0.0)*7.0);
    }
    ALBEDO=color.rgb*light*strength;
    ALPHA=clamp(light*strength,0.0,1.0)*shown*color.a;
}
