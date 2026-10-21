shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
global uniform float synk_time;
uniform sampler2D artwork : source_color, filter_linear_mipmap, repeat_disable;
uniform float half_width=9.75;
uniform float darkness=1.0;
uniform vec3 color_a : source_color=vec3(0.02,0.8,1.0);
uniform vec3 color_b : source_color=vec3(0.94,0.1,1.0);
varying vec3 world_position;
vec3 rgb_to_hsv(vec3 c) {
    vec4 k=vec4(0.0,-1.0/3.0,2.0/3.0,-1.0);
    vec4 p=mix(vec4(c.bg,k.wz),vec4(c.gb,k.xy),step(c.b,c.g));
    vec4 q=mix(vec4(p.xyw,c.r),vec4(c.r,p.yzx),step(p.x,c.r));
    float d=q.x-min(q.w,q.y);
    return vec3(abs(q.z+(q.w-q.y)/(6.0*d+0.0000001)),d/(q.x+0.0000001),q.x);
}
vec3 hsv_to_rgb(vec3 c) {
    vec3 p=abs(fract(c.xxx+vec3(0.0,2.0/3.0,1.0/3.0))*6.0-3.0);
    return c.z*mix(vec3(1.0),clamp(p-1.0,0.0,1.0),c.y);
}
void vertex() { world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
    float across=world_position.x/(half_width*2.0);
    float along=(world_position.z+60.0)/60.0;
    // Interior artwork corners: top (.419,.119)-(.581,.119), bottom (.111,.879)-(.889,.879).
    float ratio=0.162/0.778;
    float denominator=1.0+(ratio-1.0)*along;
    vec2 photo_uv=vec2(0.5+across*0.162/denominator,
        (0.119+(0.879*ratio-0.119)*along)/denominator);
    if(denominator<=0.0 || any(lessThan(photo_uv,vec2(0.0))) || any(greaterThan(photo_uv,vec2(1.0)))) discard;
    vec4 art=texture(artwork,photo_uv);
    vec3 hsv=rgb_to_hsv(art.rgb);
    float magenta=smoothstep(0.58,0.83,hsv.x);
    float a=rgb_to_hsv(color_a).x-0.53;
    float b=rgb_to_hsv(color_b).x-0.83;
    hsv.x=fract(hsv.x+mix(a,b,magenta)+0.035*sin(synk_time*0.35));
    ALBEDO=hsv_to_rgb(hsv);
    ALPHA=art.a;
}
