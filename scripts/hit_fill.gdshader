shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

uniform vec3 tint : source_color = vec3(0.9, 0.25, 1.0);
uniform float opacity = 1.0;

void fragment() {
	vec2 p = (UV - vec2(0.5, 0.68)) * vec2(2.0, 2.5);
	float center = exp(-dot(p, p) * 5.0);
	float body = exp(-dot(p * vec2(0.68, 1.15), p * vec2(0.68, 1.15)) * 2.7);
	float column = exp(-abs(p.x) * 10.0) * (1.0 - smoothstep(0.05, 0.95, UV.y));
	float fill = min(1.0, center * 0.82 + body * 0.48 + column * 0.18);
	ALBEDO = mix(tint, vec3(1.0, 0.97, 1.0), center * 0.68);
	ALPHA = fill * opacity;
}
