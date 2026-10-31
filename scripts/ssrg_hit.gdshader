shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform sampler2D atlas : source_color, filter_linear, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float frame = 0.0;
uniform float opacity = 1.0;
// Hit effects page colour: the art keeps its light and shape, with the chosen hue.
uniform bool recolor = false;
void fragment(){
    float cell=clamp(floor(frame),0.0,10.0);
    vec2 tile=vec2(mod(cell,4.0),floor(cell/4.0));
    vec2 uv=UV;
    vec4 art=texture(atlas,uv);
    float light=max(art.r,max(art.g,art.b));
    ALBEDO=recolor ? mix(tint.rgb*light,vec3(light),smoothstep(.75,1.0,light)*.6) : art.rgb*tint.rgb;
    ALPHA=art.a*opacity;
}
