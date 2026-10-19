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
varying float world_z;
void vertex(){ world_z=(MODEL_MATRIX*vec4(VERTEX,1.0)).z; }
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
    if(world_z>clip_z) discard;
    vec4 art=texture(artwork,UV);
    vec3 hsv=rgb_to_hsv(art.rgb);
    hsv.x=fract(hsv.x+hue_shift);
    hsv.y=clamp(hsv.y*saturation_scale,0.0,1.0);
    hsv.z*=value_scale;
    vec3 color=hsv_to_rgb(hsv);
    float gray=dot(color,vec3(0.299,0.587,0.114));
    ALBEDO=mix(color,vec3(gray*0.52),desaturate);
    ALPHA=art.a*opacity*ghost_fade*smoothstep(-60.0,-40.0,world_z);
}
