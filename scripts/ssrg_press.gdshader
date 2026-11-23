shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
uniform vec4 base_color : source_color = vec4(1.0,.8627451,.254902,.58431375);
uniform sampler2D artwork : source_color, filter_linear, repeat_disable;
uniform float entrance : hint_range(0.0,1.0) = 1.0;
void fragment(){
    vec4 art=texture(artwork,UV);
    ALBEDO=art.rgb*base_color.rgb;
    ALPHA=art.a*base_color.a*entrance;
}
