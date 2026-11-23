shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

uniform vec4 glow_color : source_color = vec4(1.0,.8627451,.254902,.5882353);
uniform float entrance : hint_range(0.0,1.0) = 1.0;

void fragment(){
    // UV.y=0 is the far/lower edge and UV.y=1 touches the judgment band.
    float vertical=smoothstep(0.0,.82,UV.y);
    vertical*=vertical;
    float side=smoothstep(0.0,.035,UV.x)*smoothstep(0.0,.035,1.0-UV.x);
    ALBEDO=glow_color.rgb;
    ALPHA=glow_color.a*vertical*side*.72*entrance;
}
