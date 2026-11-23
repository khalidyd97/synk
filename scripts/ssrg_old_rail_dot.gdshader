shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform sampler2D artwork : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 accent : source_color=vec4(1.0,.26,.34,1.0);
uniform vec2 rail_start=vec2(0.0);
uniform vec2 rail_end=vec2(0.0);
uniform vec2 rail_half_widths=vec2(.05,.5);
uniform float entrance : hint_range(0.0,1.0) = 1.0;
varying vec2 stage_position;
void vertex(){
    vec3 point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    stage_position=point.xz;
}
void fragment(){
    vec2 axis=rail_end-rail_start;
    float progress=clamp(dot(stage_position-rail_start,axis)/max(dot(axis,axis),.00001),0.0,1.0);
    float distance_to_rail=length(stage_position-mix(rail_start,rail_end,progress));
    float half_width=mix(rail_half_widths.x,rail_half_widths.y,progress);
    float inside=1.0-smoothstep(half_width-fwidth(distance_to_rail),half_width,distance_to_rail);
    vec3 art=texture(artwork,UV).rgb;
    float light=max(art.r,max(art.g,art.b));
    ALBEDO=accent.rgb*light;
    EMISSION=accent.rgb*light*.7;
    ALPHA=light*.85*inside*entrance;
}
