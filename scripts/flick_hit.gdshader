shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

uniform vec3 tint : source_color = vec3(0.4, 0.7, 1.0);
uniform vec2 direction = vec2(1.0, 0.0);
uniform float opacity = 1.0;
uniform float progress = 0.0;

void fragment() {
    vec2 p = (UV - vec2(0.5)) * vec2(8.0, 5.0);
    p.y = -p.y;
    float along = dot(p, direction);
    float across = dot(p, vec2(-direction.y, direction.x));
    float travel = (1.0 - pow(1.0-progress, 2.0)) * 2.6;
    // A stationary white impact blooms into a tapered, moving neon fan.
    float core = exp(-dot(p, p)*5.0) * (1.0-progress);
    float head = exp(-pow((along-travel)/0.48,2.0)-pow(across/0.38,2.0));
    float gate = smoothstep(-0.6,0.0,along) * (1.0-smoothstep(travel+0.1,travel+0.8,along));
    float width = 0.16 + max(along,0.0)*0.16;
    float body = exp(-pow(across/width,2.0)) * gate;
    float fan = 0.0;
    for (int i=0; i<5; i++) {
        float spread = float(i-2)*0.16;
        float arc = across-spread*(0.35+max(along,0.0));
        fan += exp(-pow(arc/0.045,2.0))*gate*0.45;
    }
    float halo = exp(-pow(across/(width*2.5),2.0))*gate*0.24;
    float rim = exp(-pow((length(vec2((along-travel)*0.7,across))-0.55)/0.06,2.0))
        * smoothstep(travel-0.1,travel+0.4,along)*0.55;
    float light = core+head+body*0.7+fan+halo+rim;
    float edge = (1.0-smoothstep(3.4,4.0,abs(p.x)))*(1.0-smoothstep(2.0,2.5,abs(p.y)));
    ALBEDO = mix(tint,vec3(1.0),clamp(core+head+body*0.55,0.0,1.0));
    ALPHA = clamp(light,0.0,1.0)*opacity*edge;
}
