shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
uniform float progress : hint_range(0.0,1.0) = 0.0;
uniform sampler2D artwork : source_color, filter_linear_mipmap, repeat_disable;
void fragment(){
    vec4 art=texture(artwork,UV);
    ALBEDO=art.rgb;
    ALPHA=art.a*progress;
}
