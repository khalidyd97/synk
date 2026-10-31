shader_type canvas_item;
uniform vec4 tint : source_color=vec4(.4,.2,1,1);
uniform vec4 secondary : source_color=vec4(.1,.8,1,1);
uniform vec2 rect_size=vec2(56.0);
uniform float radius=12.0;
uniform bool note_mark=false;
void fragment(){
    vec4 source=texture(TEXTURE,UV);
    // The note mark is replaced by the song's initials (a label over the cover).
    float note=note_mark ? smoothstep(.80,.98,min(source.r,min(source.g,source.b))) : 0.0;
    vec3 background=mix(tint.rgb,secondary.rgb,UV.y*.65+UV.x*.25);
    background+=vec3(.20)*exp(-length(UV-vec2(.2,.2))*6.0);
    background*=1.0-.70*smoothstep(1.35,1.85,UV.x+UV.y);
    vec2 p=UV*rect_size;
    vec2 inner=clamp(p,vec2(radius),rect_size-vec2(radius));
    float mask=1.0-smoothstep(-1.0,1.0,length(p-inner)-radius);
    // COLOR arrives as texture*modulate; keep only the modulate alpha so the note art does not show.
    float fade=source.a>0.001 ? COLOR.a/source.a : 1.0;
    COLOR=note_mark ? vec4(mix(background,vec3(1),note),source.a*mask)*COLOR : vec4(background,mask*fade);
}
