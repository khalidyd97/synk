shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;

void fragment() {
    // Plane UV.y runs from the distant entrance toward the judgment area.
    float depth = UV.y;
    float half_width = depth + 0.025;
    float within_rails = 1.0 - smoothstep(half_width - 0.018, half_width + 0.018, abs(UV.x - 0.5) * 2.0);
    float fade = 1.0 - smoothstep(0.0, 0.34, depth);
    ALBEDO = vec3(0.0);
    ALPHA = 0.94 * fade * within_rails;
}
