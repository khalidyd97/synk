shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

// A flat golden band across the highway where notes are hit. A faint sheen drifts across
// it, and the near half is a touch brighter so the band reads as lit from the front.
uniform float animation_time = 0.0;
uniform vec3 base_color : source_color = vec3(1.0, 0.86, 0.34);
uniform vec3 sweep_color : source_color = vec3(1.0, 0.95, 0.72);

void fragment() {
	float position = fract(animation_time * 0.08);
	float distance_to_sweep = abs(UV.x - position);
	float sheen = exp(-distance_to_sweep * distance_to_sweep * 90.0);
	vec3 color = mix(base_color * 0.88, base_color, smoothstep(0.0, 1.0, UV.y));
	ALBEDO = mix(color, sweep_color, 0.18 * sheen);
	float edge = smoothstep(0.0, 0.06, UV.y) * smoothstep(0.0, 0.06, 1.0 - UV.y);
	ALPHA = (0.84 + 0.05 * sheen) * (0.88 + 0.12 * edge);
}
