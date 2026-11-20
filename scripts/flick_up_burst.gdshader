shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
// A short-lived burst spawned when an up-flick is hit: an upward chevron with motion
// streaks that shoots up from the hit point and fades, so the flash reads as "up".
uniform vec3 tint : source_color = vec3(1.0, 0.96, 1.0);
uniform float progress = 0.0;   // 0 at the hit, 1 when the burst has faded out
global uniform float synk_note_brightness;

float segment_distance(vec2 p, vec2 a, vec2 b) {
	vec2 edge = b - a;
	return length(p - a - edge * clamp(dot(p - a, edge) / dot(edge, edge), 0.0, 1.0));
}

void fragment() {
	vec2 p = (UV - vec2(0.5)) * vec2(3.22, 1.6);
	// Upward chevron (apex toward -y, which is screen-up on the billboard).
	float d = min(segment_distance(p, vec2(-0.72, 0.30), vec2(0.0, -0.44)),
				  segment_distance(p, vec2(0.0, -0.44), vec2(0.72, 0.30)));
	float core = 1.0 - smoothstep(0.07, 0.13, d);
	float glow = exp(-d * d * 40.0) * 0.5;
	// Vertical motion streaks trailing below the chevron, strongest at the start.
	float streak = exp(-abs(p.x) * 2.4) * smoothstep(0.55, -0.45, p.y) * 0.6 * (1.0 - progress);
	float pop = smoothstep(0.0, 0.14, progress);
	float fade = pow(1.0 - progress, 1.3);
	vec3 color = mix(tint, vec3(1.0, 0.97, 1.0), core);
	ALBEDO = color * synk_note_brightness;
	ALPHA = clamp((core + glow + streak), 0.0, 1.0) * fade * pop;
}
