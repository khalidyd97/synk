shader_type canvas_item;
// 2D copy of the highway note colouring, so previews show the notes as they look in play.
// round: hue-rotate the circle/puck art (reference_note.gdshader). Otherwise recolour the
// tap/hold art toward a tint the way neon_asset.gdshader does.
uniform bool round_art = true;
uniform float hue_shift = 0.0;
uniform float saturation_scale = 1.0;
uniform float value_scale = 1.0;
uniform bool recolor = false;
uniform vec3 tint : source_color = vec3(0.6, 0.2, 1.0);
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0);
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
    vec4 art=texture(TEXTURE,region.xy+UV*region.zw);
    if(round_art){
        vec3 hsv=rgb_to_hsv(art.rgb);
        hsv.x=fract(hsv.x+hue_shift);
        hsv.y=clamp(hsv.y*saturation_scale,0.0,1.0);
        hsv.z*=value_scale;
        COLOR=vec4(hsv_to_rgb(hsv),art.a);
    } else {
        float peak=max(art.r,max(art.g,art.b));
        float white=min(art.r,min(art.g,art.b))/max(peak,0.001);
        vec3 c=recolor ? mix(tint,vec3(1.0),white*white)*peak : art.rgb;
        COLOR=vec4(c,art.a*smoothstep(0.025,0.13,peak));
    }
}
