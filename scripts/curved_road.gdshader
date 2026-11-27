shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;
// Curved highway (test): a purple road whose glowing edges rise almost straight up far away
// and flare out toward the player, meeting the judgment bar in rounded corners. The road's
// width follows ssrg_width(), the same curve the notes and lanes use.
#include "res://scripts/ssrg_warp.gdshaderinc"
uniform float pixel = 1.0;          // screen pixels per 720p pixel
uniform vec3 line_color : source_color = vec3(.71,.48,1.0);
uniform vec3 glow_color : source_color = vec3(.48,.17,1.0);
uniform vec3 core_color : source_color = vec3(.96,.91,1.0);
uniform vec3 floor_far : source_color = vec3(.02,.0,.05);
uniform vec3 floor_near : source_color = vec3(.15,.04,.32);
const float R = 9.75;
const float CORNER = 34.0;          // radius of the rounded corners, in 720p pixels
varying float canvas_x;
varying float canvas_z;
void vertex(){
    VERTEX=ssrg_warp_canvas(VERTEX,MODEL_MATRIX);
    vec3 w=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    canvas_x=w.x; canvas_z=w.z;
}
float smooth_min(float a, float b, float k){ return -k*log(exp(-a/k)+exp(-b/k)); }
void fragment(){
    // Height on the canvas: 0 far end, 1 judgment line. Exact for every pixel, so the
    // road's edges stay smooth however coarse the mesh is.
    float q=1.0+canvas_z/ssrg_warp.z;
    float width=max(ssrg_width(q),.0001);
    float x=(canvas_x-ssrg_bend_at(q))/width;
    // Distances in 720p pixels, measured on screen.
    float edge=abs(x)-R;
    float edge_px=edge/max(length(vec2(dFdx(x),dFdy(x))),1e-5)/pixel;
    float bar_px=canvas_z/max(length(vec2(dFdx(canvas_z),dFdy(canvas_z))),1e-5)/pixel;
    float d;
    if(edge>0.0&&bar_px>0.0) d=length(vec2(edge_px,bar_px));
    else if(edge>0.0) d=edge_px;
    else if(bar_px>0.0) d=bar_px;
    else d=smooth_min(-edge_px,-bar_px,CORNER*.35);
    // The edges thin out toward the far end; the bar keeps its full weight.
    float weight=mix(.28,1.0,clamp(width,0.0,1.0));
    // Near the bar the line takes the bar's heavier weight, through the rounded corners too.
    weight=mix(weight,1.55,clamp(1.0+bar_px/45.0,0.0,1.0));
    float core_w=3.2*weight, line_w=6.5*weight, glow_w=18.0*weight;
    float core=exp(-pow(d/core_w,2.0));
    float line=exp(-pow(d/line_w,2.0));
    float glow=exp(-max(d-line_w*.5,0.0)/glow_w);
    bool inside=edge<0.0&&bar_px<0.0;
    float h=clamp(q,0.0,1.0);
    vec3 floor_color=mix(floor_far,floor_near,pow(h,1.6));
    // Light from the bar spreads up over the road just above it.
    floor_color+=glow_color*(.6*exp(bar_px/55.0)+.18*exp(bar_px/220.0))*float(bar_px<0.0);
    vec3 light=core_color*core+line_color*line*.9+glow_color*glow*.55;
    float light_alpha=clamp(core+line*.9+glow*.55,0.0,1.0);
    // Fade in where the notes appear, under the cover far up the road.
    float progress=pow(max(q,0.0),1.0/ssrg_warp.y);
    float fade=smoothstep(.44,.56,progress);
    vec3 color=inside?floor_color+light:light/max(light_alpha,.001);
    float alpha=inside?.97:light_alpha;
    ALBEDO=min(color,vec3(1.6));
    ALPHA=clamp(alpha,0.0,1.0)*fade;
}
