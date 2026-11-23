shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
uniform sampler2D artwork : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 accent : source_color = vec4(1.0,.26,.34,1.0);
uniform float motion_time=0.0;
uniform float entrance : hint_range(0.0,1.0) = 1.0;
void fragment(){
    vec4 line=texture(artwork,UV);
    float center=.5+.45*sin(motion_time*1.5);
    float packet=exp(-pow((UV.x-center)*38.0,2.0));
    ALBEDO=accent.rgb*(.7+1.2*packet)*line.rgb;
    EMISSION=accent.rgb*(.3+1.5*packet)*line.rgb;
    ALPHA=line.a*(.72+.28*packet)*entrance;
}
