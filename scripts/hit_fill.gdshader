shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform vec3 tint : source_color = vec3(0.9, 0.25, 1.0);
uniform float opacity = 1.0;
void fragment() {
    vec2 p = (UV - vec2(0.5, 0.68)) * vec2(2.0, 2.5);
    float center = exp(-dot(p, p) * 3.0);
    float body = exp(-dot(p * vec2(0.62, 0.88), p * vec2(0.62, 0.88)) * 2.1);
    float column = exp(-abs(p.x) * 6.0) * (1.0 - smoothstep(0.05, 0.95, UV.y));
    float edge = smoothstep(0.0, 0.12, UV.x) * smoothstep(0.0, 0.12, 1.0-UV.x)
        * smoothstep(0.0, 0.12, UV.y) * smoothstep(0.0, 0.12, 1.0-UV.y);
    float fill = min(1.0, center * 1.02 + body * 0.68 + column * 0.25) * edge;
    ALBEDO = mix(tint, vec3(1.0, 0.97, 1.0), center * 0.68);
    ALPHA = fill * opacity;
}
