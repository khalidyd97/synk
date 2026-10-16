shader_type canvas_item;
render_mode blend_mix;

uniform vec3 accent : source_color = vec3(0.70, 0.35, 1.0);
// Second gradient stop for filled buttons; equal to `accent` for a flat color.
uniform vec3 accent_end : source_color = vec3(0.70, 0.35, 1.0);
uniform float aspect = 4.0;
uniform float hover_amount = 0.0;
uniform float press_amount = 0.0;
uniform float disabled_amount = 0.0;
uniform float selected_amount = 0.0;
uniform float ring_strength = 1.0;
// Design-system controls (see VARIANTS in neon_action.gd).
uniform float slant = 1.0;          // 1 = slanted action plate, 0 = rounded tool chip
uniform float fill_amount = 0.0;    // 1 = solid gradient body
uniform float selected_fill = 0.0;  // body fill added while selected (toggles, current tool)
uniform float rim_strength = 1.0;
uniform float ghost = 0.0;          // 1 = no body, used for navigation
uniform float glare = 0.0;

void fragment() {
	// All edge distances are measured in units of the button's height.
	float left_edge = 0.055 * (1.0 - UV.y);
	float right_edge = 1.0 - 0.055 * UV.y;
	float plate_edge = min(min((UV.x - left_edge) * aspect, (right_edge - UV.x) * aspect), min(UV.y - 0.10, 0.90 - UV.y));
	vec2 point = vec2(UV.x * aspect, UV.y);
	float radius_corner = 0.24;
	vec2 half_size = vec2(aspect * 0.5 - 0.03, 0.39);
	vec2 q = abs(point - vec2(aspect * 0.5, 0.5)) - half_size + radius_corner;
	float chip_edge = -(length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius_corner);
	float edge = mix(chip_edge, plate_edge, slant);
	float inside = smoothstep(-0.012, 0.006, edge);
	float rim = exp(-pow(edge / 0.018, 2.0)) * rim_strength;
	float halo = exp(-pow(edge / 0.066, 2.0)) * mix(0.55, 1.0, rim_strength);
	float sweep_x = fract(TIME * 0.19) * 1.35 - 0.18;
	float sweep = exp(-pow((UV.x - sweep_x) / 0.035, 2.0)) * inside * glare;
	vec2 ring_point = (UV - vec2(0.23, 0.5)) * vec2(aspect, 1.0);
	float radius = length(ring_point);
	float rings = exp(-pow((radius - 0.26) / 0.018, 2.0))
		+ 0.55 * exp(-pow((radius - 0.39) / 0.017, 2.0));
	rings *= (1.0 - smoothstep(0.24, 0.49, UV.x)) * inside * ring_strength * glare;
	float energy = 0.84 + hover_amount * 0.35 + selected_amount * 0.25;
	float fill = clamp(fill_amount + selected_amount * selected_fill, 0.0, 1.0);
	vec3 dark = mix(vec3(0.015, 0.010, 0.060), accent * 0.18, UV.x);
	vec3 solid = mix(accent, accent_end, UV.x) * (0.80 - 0.22 * UV.y + hover_amount * 0.12);
	solid += vec3(1.0) * smoothstep(0.55, 0.12, UV.y) * 0.10 * glare;
	vec3 body = mix(dark, solid, fill) * inside * (1.0 - ghost);
	float rail = (1.0-smoothstep(0.014,0.026,abs(UV.y-0.85))) * step(0.12,UV.x) * step(UV.x,0.88) * inside;
	float marker = step(UV.x * aspect,0.13) * step(0.28,UV.y) * step(UV.y,0.72) * inside;
	body += accent * (rail * (0.12+selected_amount*.8) + marker * (0.3+selected_amount*.7));
	vec3 color = body + accent * (rim * 1.65 * energy + halo * 0.18 + rings * 0.58 + sweep * (0.23 + hover_amount * 0.25) * (1.0 - ghost));
	color += vec3(0.58, 0.41, 0.95) * rim * 0.28;
	color *= 1.0 + press_amount * 0.28;
	color = mix(color, color * 0.38, disabled_amount);
	float body_alpha = mix(0.93, 0.12 + hover_amount * 0.18, ghost);
	float alpha = clamp(inside * body_alpha + halo * 0.55 + rim, 0.0, 1.0);
	COLOR = vec4(color, alpha);
}
