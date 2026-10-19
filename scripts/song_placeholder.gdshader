shader_type canvas_item;
uniform vec4 tint : source_color=vec4(.4,.2,1,1);
uniform vec4 secondary : source_color=vec4(.1,.8,1,1);
uniform vec2 rect_size=vec2(56.0);
uniform float radius=12.0;
void fragment(){
    vec4 source=texture(TEXTURE,UV);
    float note=smoothstep(.80,.98,min(source.r,min(source.g,source.b)));
    vec3 background=mix(tint.rgb,secondary.rgb,UV.y*.65+UV.x*.25);
    background+=vec3(.20)*exp(-length(UV-vec2(.2,.2))*6.0);
    background*=1.0-.70*smoothstep(1.35,1.85,UV.x+UV.y);
    vec2 p=UV*rect_size;
    vec2 inner=clamp(p,vec2(radius),rect_size-vec2(radius));
    float mask=1.0-smoothstep(-1.0,1.0,length(p-inner)-radius);
    COLOR=vec4(mix(background,vec3(1),note),source.a*mask)*COLOR;
}
