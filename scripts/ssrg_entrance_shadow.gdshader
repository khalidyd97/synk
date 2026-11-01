shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;
uniform sampler2D rail_art : source_color, filter_linear, repeat_disable;

void fragment() {
    // Plane UV.y runs from the distant entrance toward the judgment area.
    float depth = UV.y;
    // Match the actual mirrored rail sprites, including their inner bevel,
    // instead of estimating the highway edge with a narrower triangle.
    vec2 ui = vec2((UV.x - 0.5) * 1440.0, 280.0 - depth * 600.0);
    vec2 rail_uv = vec2(1.0 - abs(ui.x) / 720.0, (258.0 - ui.y) / 578.0);
    vec4 rail = texture(rail_art, rail_uv);
    float light = max(rail.r, max(rail.g, rail.b));
    float within_rails = smoothstep(0.01, 0.1, rail.a) * (1.0 - smoothstep(0.01, 0.035, light));
    if (rail_uv.y < 0.0 || rail_uv.y > 1.0) within_rails = 0.0;
    float fade = 1.0 - smoothstep(0.0, 0.34, depth);
    ALBEDO = vec3(0.0);
    ALPHA = 0.94 * fade * within_rails;
}
