shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

// Recorder pad: SSRG's thirteen channels as soft rounded slots on dark glass.
// Each slot matches one SSRG touch rectangle (62.7 units wide). A held finger lights
// its slot; the centre channel carries a faint tick so the middle is easy to find.
uniform float lit[13];
uniform vec4 slot_color : source_color = vec4(0.957, 0.945, 0.918, 0.06);
uniform vec4 lit_color : source_color = vec4(1.0, 0.541, 0.357, 0.85);
uniform vec4 glass_color : source_color = vec4(0.06, 0.06, 0.07, 0.78);
// Fraction of the quad width covered by the 13 channels (the rest is the outer rim).
uniform float span = 0.9;

#include "res://scripts/ssrg_warp.gdshaderinc"
void vertex(){VERTEX=ssrg_warp_canvas(VERTEX,MODEL_MATRIX);}

float rounded_box(vec2 p, vec2 half_size, float r){
	vec2 q = abs(p) - half_size + vec2(r);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment(){
	vec2 uv = UV;
	float x = (uv.x - 0.5) / span + 0.5;
	float fx = x * 13.0;
	int lane = int(clamp(floor(fx), 0.0, 12.0));
	vec2 local = vec2(fract(fx) - 0.5, uv.y - 0.5);
	// Slot size in lane units: a little gap between neighbours, nearly full depth.
	float aspect = 0.62;
	float d = rounded_box(local * vec2(1.0, aspect), vec2(0.42, 0.36 * aspect), 0.12);
	float inside = (x >= 0.0 && x <= 1.0) ? 1.0 - smoothstep(-0.01, 0.01, d) : 0.0;
	float rim = (x >= 0.0 && x <= 1.0) ? (1.0 - smoothstep(0.0, 0.025, abs(d))) : 0.0;
	float on = clamp(lit[lane], 0.0, 1.0);
	vec4 color = glass_color;
	color.rgb = mix(color.rgb, slot_color.rgb, inside * slot_color.a);
	color.rgb = mix(color.rgb, slot_color.rgb, rim * 0.45);
	color.rgb = mix(color.rgb, lit_color.rgb, inside * on * lit_color.a);
	// Centre channel tick.
	if (lane == 6) color.rgb = mix(color.rgb, slot_color.rgb, 0.5 * (1.0 - smoothstep(0.0, 0.03, abs(local.x))) * step(abs(local.y), 0.08));
	float edge = smoothstep(0.0, 0.04, uv.y) * smoothstep(0.0, 0.04, 1.0 - uv.y);
	ALBEDO = color.rgb;
	ALPHA = max(glass_color.a, inside * (slot_color.a + on * lit_color.a)) * edge;
}
