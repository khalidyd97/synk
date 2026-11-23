shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
uniform sampler2D artwork : source_color, filter_linear_mipmap, repeat_disable;
uniform bool along_rail = true;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec3 floor_tint : source_color = vec3(0.0);
uniform float floor_opacity = 1.0;
uniform float rail_entrance : hint_range(0.0,1.0) = 1.0;
uniform float floor_entrance : hint_range(0.0,1.0) = 1.0;
uniform float rail_side = 1.0;
void vertex(){
    // Each half arrives gently from its outer edge while its rail is being drawn.
    VERTEX.x+=rail_side*(1.0-rail_entrance)*.72;
}
void fragment(){
    vec2 uv=along_rail ? vec2(1.0-UV.y,UV.x) : UV;
    vec4 art=texture(artwork,uv);
    bool road=max(art.r,max(art.g,art.b))<0.05;
    // Draw the rail down its length instead of fading the complete silhouette at once.
    float rail_wipe=1.0-smoothstep(rail_entrance,rail_entrance+.075,UV.y);
    float leading_edge=exp(-pow((UV.y-rail_entrance)*24.0,2.0))
        *smoothstep(0.0,.08,rail_entrance)*(1.0-smoothstep(.88,1.0,rail_entrance));
    ALBEDO=road?floor_tint:art.rgb*tint.rgb*(1.0+leading_edge*1.65);
    EMISSION=road?vec3(0.0):art.rgb*tint.rgb*leading_edge*.85;
    ALPHA=art.a*tint.a*(road?floor_opacity*floor_entrance:rail_wipe*smoothstep(0.0,.16,rail_entrance));
}
