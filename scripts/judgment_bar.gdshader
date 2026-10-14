shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

uniform float animation_time = 0.0;

void fragment() {
	float position = fract(animation_time * 0.12);
	float distance_to_sweep = abs(UV.x - position);
	float sweep = exp(-distance_to_sweep * distance_to_sweep * 520.0);
	float soft_glow = exp(-distance_to_sweep * distance_to_sweep * 55.0);
	float edge = smoothstep(0.0, 0.12, UV.y) * smoothstep(0.0, 0.12, 1.0 - UV.y);
	vec3 purple = vec3(0.60, 0.36, 1.0);
	vec3 cyan = vec3(0.68, 0.91, 1.0);
	ALBEDO = mix(purple, cyan, 0.24 * soft_glow + 0.58 * sweep);
	ALPHA = (0.63 + 0.11 * soft_glow + 0.15 * sweep) * (0.92 + 0.08 * edge);
}
