shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
uniform vec4 base_color : source_color = vec4(1.0,.8627451,.254902,.58431375);
uniform sampler2D artwork : source_color, filter_linear, repeat_disable;
uniform float entrance : hint_range(0.0,1.0) = 1.0;
void fragment(){
    vec4 art=texture(artwork,UV);
    // Build outward from the centre, followed by one bright impact that settles
    // into the source judgment artwork instead of reading as a plain fade.
    float radius=smoothstep(0.0,.78,entrance)*.58;
    float distance_from_centre=abs(UV.x-.5);
    float reveal=1.0-smoothstep(radius,radius+.055,distance_from_centre);
    float wave=exp(-pow((distance_from_centre-radius)*28.0,2.0));
    float burst=exp(-pow((entrance-.58)*7.5,2.0));
    ALBEDO=art.rgb*base_color.rgb*(1.0+burst*.9)+base_color.rgb*wave*burst*.8;
    ALPHA=art.a*base_color.a*reveal*clamp(entrance*2.4+wave*burst*.75,0.0,1.35);
}
