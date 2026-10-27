shader_type spatial;
render_mode unshaded, blend_mix, depth_prepass_alpha, cull_disabled, fog_disabled;
uniform sampler2D artwork : source_color, filter_linear_mipmap, repeat_disable;
uniform float hue_shift = 0.0;
uniform float saturation_scale = 1.0;
uniform float value_scale = 1.0;
uniform float opacity = 1.0;
uniform float ghost_fade = 1.0;
uniform float desaturate = 0.0;
uniform float clip_z = 1000.0;
// SSRG Playables: falling notes play a 6-frame glow loop like a sprite sequence (white-hot
// centre and halo down to the plain colour, then again), and stay hot over the last
// `glow_distance` units before the judgement line.
uniform bool approach_glow = false;
uniform float glow_distance = 7.0;
// Colour of the note's glass centre when it is not glowing (blue taps, gold holds).
uniform vec3 core_tint : source_color = vec3(0.32, 0.78, 1.0);
const float GLOW_FRAMES = 6.0;
const float GLOW_LOOPS_PER_SECOND = 2.2;
global uniform float synk_time;
varying float world_z;
varying float centre_z;
#include "res://scripts/ssrg_warp.gdshaderinc"
// world_z and centre_z stay linear track positions for clipping, fading and the glow.
void vertex(){ world_z=(MODEL_MATRIX*vec4(VERTEX,1.0)).z; centre_z=MODEL_MATRIX[3].z; VERTEX=ssrg_warp_rigid(VERTEX,MODEL_MATRIX); }
// Rotate hue only: value, saturation, white highlights and source alpha survive intact.
vec3 rgb_to_hsv(vec3 c){
    vec4 k=vec4(0.0,-1.0/3.0,2.0/3.0,-1.0);
    vec4 p=mix(vec4(c.bg,k.wz),vec4(c.gb,k.xy),step(c.b,c.g));
    vec4 q=mix(vec4(p.xyw,c.r),vec4(c.r,p.yzx),step(p.x,c.r));
    float d=q.x-min(q.w,q.y);
    return vec3(abs(q.z+(q.w-q.y)/(6.0*d+0.0000001)),d/(q.x+0.0000001),q.x);
}
vec3 hsv_to_rgb(vec3 c){
    vec3 p=abs(fract(c.xxx+vec3(0.0,2.0/3.0,1.0/3.0))*6.0-3.0);
    return c.z*mix(vec3(1.0),clamp(p-1.0,0.0,1.0),c.y);
}
void fragment(){
    if((ssrg_warp.x>0.5?centre_z:world_z)>clip_z) discard;
    vec4 art=texture(artwork,UV);
    vec3 hsv=rgb_to_hsv(art.rgb);
    hsv.x=fract(hsv.x+hue_shift);
    hsv.y=clamp(hsv.y*saturation_scale,0.0,1.0);
    hsv.z*=value_scale;
    vec3 color=hsv_to_rgb(hsv);
    float gray=dot(color,vec3(0.299,0.587,0.114));
    float alpha=art.a;
    if(approach_glow){
        // Stepped frame 0..5 (0 = hottest), offset by position so notes do not pulse in unison.
        float frame=floor(fract(synk_time*GLOW_LOOPS_PER_SECOND+centre_z*0.031)*GLOW_FRAMES);
        float loop_heat=1.0-frame/(GLOW_FRAMES-1.0);
        float near=pow(clamp(1.0+centre_z/glow_distance,0.0,1.0),1.4);
        // Mostly the plain colour: the loop only tints, the full white is kept for the line.
        float heat=max(loop_heat*0.45,near*0.8);
        float bright=dot(art.rgb,vec3(0.3,0.55,0.15));
        // Cool: the white centre takes the note's colour; hot: it burns back to white.
        float centre_mask=smoothstep(0.55,0.95,bright);
        color=mix(color,core_tint*(0.55+0.45*bright),centre_mask*(1.0-heat)*0.8);
        color=mix(color,vec3(1.0),heat*centre_mask*0.7);
        // Halo: the blurred note shape (a low mip) around the edge, white-tinted.
        float halo=textureLod(artwork,UV,4.0).a;
        float rim=heat*halo*(1.0-art.a)*0.45;
        color=mix(color,vec3(1.0),rim/max(0.001,alpha+rim));
        alpha=max(alpha,rim);
    }
    ALBEDO=mix(color,vec3(gray*0.52),desaturate);
    ALPHA=alpha*opacity*ghost_fade*smoothstep(-60.0,-55.0,world_z)*ssrg_reveal(centre_z);
}
