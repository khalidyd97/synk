shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
global uniform float synk_time;
uniform vec3 base_color : source_color=vec3(0.02,0.8,1.0);
uniform vec3 sweep_color : source_color=vec3(0.94,0.1,1.0);
void fragment() {
    float wave=0.5+0.5*sin(UV.x*6.283-synk_time*0.7);
    vec3 neon=mix(base_color,sweep_color,wave);
    float edge=pow(abs(UV.y*2.0-1.0),18.0);
    ALBEDO=neon*(0.35+edge*0.8)+vec3(0.5)*edge;
    ALPHA=0.5+edge*0.45;
}
