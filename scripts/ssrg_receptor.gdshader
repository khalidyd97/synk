shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
uniform float progress : hint_range(0.0,1.0) = 0.0;
void fragment(){
    vec2 point=(UV-.5)*2.0;
    float radius=length(point);
    float outer=exp(-pow((radius-.88)*45.0,2.0));
    float inner=exp(-pow((radius-.66)*20.0,2.0));
    float haze=exp(-pow((radius-.83)*8.0,2.0));
    ALBEDO=vec3(.96,.98,1.0);
    ALPHA=(outer*.55+inner*.85+haze*.14)*smoothstep(0.0,1.0,progress);
}
