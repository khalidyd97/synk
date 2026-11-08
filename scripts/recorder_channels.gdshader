shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

// Recorder pad: SSRG's thirteen channels on a soft dark band.
// Hairline dividers mark each channel (62.7 SSRG units wide) and fade out toward the
// band's edges; a thin judgment line runs across the middle. A held finger lights its
// channel as a soft coral glow with a bright core on the judgment line.
uniform float lit[13];
uniform vec4 slot_color : source_color = vec4(0.957, 0.945, 0.918, 0.06);
uniform vec4 lit_color : source_color = vec4(1.0, 0.541, 0.357, 0.85);
uniform vec4 glass_color : source_color = vec4(0.06, 0.06, 0.07, 0.78);
// Fraction of the quad width covered by the 13 channels (the rest is the outer rim).
uniform float span = 0.9;

#include "res://scripts/ssrg_warp.gdshaderinc"
void vertex(){VERTEX=ssrg_warp_canvas(VERTEX,MODEL_MATRIX);}

void fragment(){
	vec2 uv = UV;
	float x = (uv.x - 0.5) / span + 0.5;
	// The pad fills the whole highway. Inner channels keep SSRG's exact width; channels 1
	// and 13 stretch to the rails, matching input (a touch past them counts as the edge lane).
	float inside_x = 1.0;
	float fx = x * 13.0;
	int lane = int(clamp(floor(fx), 0.0, 12.0));
	float left_edge = (0.5 - 0.5 / span) * 13.0;
	float right_edge = (0.5 + 0.5 / span) * 13.0;
	float lane_lo = lane == 0 ? left_edge : float(lane);
	float lane_hi = lane == 12 ? right_edge : float(lane + 1);
	float lx = (fx - (lane_lo + lane_hi) * 0.5) / (lane_hi - lane_lo);   // -0.5..0.5 across the channel
	float dy = uv.y - 0.5;               // 0 on the judgment line
	// Soft vertical falloff: strongest at the judgment line, gone at the band edges.
	float band = 1.0 - smoothstep(0.18, 0.5, abs(dy));
	// Hairline dividers between channels only (the rails are the outer edges), fading vertically.
	float px = fwidth(fx);
	float nearest = floor(fx + 0.5);
	float divider = (1.0 - smoothstep(0.0, px * 1.5, abs(fx - nearest))) * step(1.0, nearest) * step(nearest, 12.0);
	divider *= 1.0 - smoothstep(0.08, 0.42, abs(dy));
	// Judgment line across the channels.
	float py = fwidth(uv.y);
	float line = (1.0 - smoothstep(0.0, py * 1.5, abs(dy))) * inside_x;
	// Lit channel: soft glow with rounded sides, plus a bright core on the line.
	float on = clamp(lit[lane], 0.0, 1.0) * inside_x;
	float side = 1.0 - smoothstep(0.30, 0.48, abs(lx));
	float glow = on * side * (1.0 - smoothstep(0.0, 0.42, abs(dy)));
	float core = on * side * (1.0 - smoothstep(0.0, 0.06, abs(dy)));
	// Centre channel: a small dot on the judgment line.
	float dot_mark = (lane == 6) ? (1.0 - smoothstep(0.03, 0.055, length(vec2(lx * 0.62, dy)))) * inside_x : 0.0;

	vec3 color = glass_color.rgb;
	float alpha = glass_color.a * band;
	color = mix(color, slot_color.rgb, divider * 0.9);
	alpha = max(alpha, divider * 0.14);
	color = mix(color, slot_color.rgb, line * 0.8);
	alpha = max(alpha, line * 0.32);
	color = mix(color, slot_color.rgb, dot_mark * 0.7);
	alpha = max(alpha, dot_mark * 0.5);
	color = mix(color, lit_color.rgb, glow * 0.85);
	alpha = max(alpha, glow * lit_color.a * 0.9);
	color = mix(color, vec3(1.0, 0.86, 0.78), core);
	alpha = max(alpha, core * 0.95);
	ALBEDO = color;
	ALPHA = alpha;
}
