shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
// The recorder's own note face: a flat rounded bar lying on the track, the same for every
// note type and coloured by type. It ignores the note style chosen for play.
uniform vec4 tint : source_color = vec4(0.3, 0.75, 1.0, 1.0);
uniform float aspect = 3.0;
uniform float ghost_fade = 1.0;
uniform float glow_pulse = 0.0;

float bar(vec2 p, vec2 half_size, float radius) {
	vec2 q = abs(p) - half_size + radius;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

void fragment() {
	vec2 p = (UV - 0.5) * vec2(aspect, 1.0);
	float d = bar(p, vec2(aspect * 0.5 - 0.04, 0.46), 0.3);
	float edge = fwidth(d) + 0.002;
	float body = 1.0 - smoothstep(-edge, edge, d);
	// A bright rim and a soft light band along the top keep the bar readable on the dark track.
	float rim = smoothstep(-0.16, -0.06, d);
	float band = smoothstep(0.30, 0.0, abs(p.y + 0.14)) * 0.35;
	vec3 colour = mix(tint.rgb * 0.82, vec3(1.0), rim * 0.75 + band);
	ALBEDO = colour;
	ALPHA = body * tint.a * ghost_fade;
}
