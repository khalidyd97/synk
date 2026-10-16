shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform vec3 tint : source_color = vec3(0.3,0.7,1.0);
uniform float opacity = 1.0;
uniform float progress = 0.0;
void fragment() {
    float radius=length((UV-vec2(0.5))*2.0);
    float ring_radius=mix(0.26,0.70,progress);
    float ring=exp(-pow((radius-ring_radius)/0.045,2.0));
    float halo=exp(-pow((radius-ring_radius)/0.16,2.0))*0.32;
    float core=(1.0-smoothstep(0.13,0.36,radius))*(1.0-progress*0.7);
    float edge=1.0-smoothstep(0.84,0.98,radius);
    ALBEDO=mix(tint,vec3(1.0,0.98,1.0),clamp(core*0.85+ring*0.45,0.0,0.9));
    ALPHA=clamp(core+ring*0.85+halo,0.0,1.0)*edge*opacity;
}
