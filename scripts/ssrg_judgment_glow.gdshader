shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

uniform vec4 glow_color : source_color = vec4(1.0,.8627451,.254902,.5882353);
uniform float entrance : hint_range(0.0,1.0) = 1.0;

void fragment(){
    // UV.y=0 is the far/lower edge and UV.y=1 touches the judgment band.
    float vertical=smoothstep(0.0,.82,UV.y);
    vertical*=vertical;
    float side=smoothstep(0.0,.035,UV.x)*smoothstep(0.0,.035,1.0-UV.x);
    float distance_from_centre=abs(UV.x-.5);
    float radius=smoothstep(0.0,.82,entrance)*.62;
    float reveal=1.0-smoothstep(radius,radius+.09,distance_from_centre);
    float wave=exp(-pow((distance_from_centre-radius)*20.0,2.0));
    float burst=exp(-pow((entrance-.56)*6.5,2.0));
    ALBEDO=glow_color.rgb*(1.0+burst*1.8+wave*1.2);
    ALPHA=glow_color.a*vertical*side*reveal*(.32+entrance*.4+wave*burst*1.45);
}
