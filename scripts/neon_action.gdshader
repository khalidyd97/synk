shader_type canvas_item;
render_mode blend_mix;

uniform vec3 accent : source_color = vec3(0.70, 0.35, 1.0);
uniform float aspect = 4.0;
uniform float hover_amount = 0.0;
uniform float press_amount = 0.0;
uniform float disabled_amount = 0.0;
uniform float selected_amount = 0.0;
uniform float ring_strength = 1.0;

void fragment() {
	float left_edge = 0.11 - 0.09 * UV.y;
	float right_edge = 0.995 - 0.11 * UV.y;
	float edge = min(min((UV.x - left_edge) * aspect, (right_edge - UV.x) * aspect), min(UV.y - 0.10, 0.90 - UV.y));
	float inside = smoothstep(-0.012, 0.006, edge);
	float rim = exp(-pow(edge / 0.018, 2.0));
	float halo = exp(-pow(edge / 0.066, 2.0));
	float sweep_x = fract(TIME * 0.19) * 1.35 - 0.18;
	float sweep = exp(-pow((UV.x - sweep_x) / 0.035, 2.0)) * inside;
	vec2 ring_point = (UV - vec2(0.23, 0.5)) * vec2(aspect, 1.0);
	float radius = length(ring_point);
	float rings = exp(-pow((radius - 0.26) / 0.018, 2.0))
		+ 0.55 * exp(-pow((radius - 0.39) / 0.017, 2.0));
	rings *= (1.0 - smoothstep(0.24, 0.49, UV.x)) * inside * ring_strength;
	float energy = 0.78 + 0.10 * sin(TIME * 2.1) + hover_amount * 0.35 + selected_amount * 0.25;
	vec3 body = mix(vec3(0.015, 0.010, 0.060), accent * 0.18, UV.x) * inside;
	vec3 color = body + accent * (rim * 1.65 * energy + halo * 0.18 + rings * 0.58 + sweep * (0.23 + hover_amount * 0.25));
	color += vec3(0.58, 0.41, 0.95) * rim * 0.28;
	color *= 1.0 + press_amount * 0.28;
	color = mix(color, color * 0.38, disabled_amount);
	float alpha = clamp(inside * 0.93 + halo * 0.55, 0.0, 1.0);
	COLOR = vec4(color, alpha);
}
