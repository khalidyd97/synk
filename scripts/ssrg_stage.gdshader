shader_type spatial;
render_mode unshaded, blend_mix, depth_prepass_alpha, cull_disabled, fog_disabled;
uniform sampler2D artwork : source_color, filter_linear_mipmap, repeat_disable;
uniform bool along_rail = true;
uniform vec4 tint : source_color = vec4(1.0);
void fragment(){
    vec2 uv=along_rail ? vec2(1.0-UV.y,UV.x) : UV;
    vec4 art=texture(artwork,uv);
    ALBEDO=art.rgb*tint.rgb;
    ALPHA=art.a*tint.a;
}
