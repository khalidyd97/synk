shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
uniform vec3 base_color : source_color = vec3(.58,.45,.12);
void fragment(){
    float edge=smoothstep(0.0,.10,UV.y)*(1.0-smoothstep(.85,1.0,UV.y));
    ALBEDO=base_color;
    ALPHA=edge*.96;
}
