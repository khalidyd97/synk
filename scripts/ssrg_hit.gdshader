shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform sampler2D atlas : source_color, filter_linear, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float frame = 0.0;
uniform float opacity = 1.0;
void fragment(){
    float cell=clamp(floor(frame),0.0,10.0);
    vec2 tile=vec2(mod(cell,4.0),floor(cell/4.0));
    vec2 uv=UV;
    ALBEDO=texture(atlas,uv).rgb*tint.rgb;
    ALPHA=opacity;
}
