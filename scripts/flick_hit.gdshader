shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

uniform vec3 tint : source_color = vec3(0.64, 0.42, 1.0);
uniform float opacity = 1.0;
uniform float progress = 0.0;

float stroke(float distance_value, float width) {
	return 1.0 - smoothstep(width, width + 0.018, distance_value);
}

void fragment() {
	vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y);
	// A tapered blade launches through three staggered chevrons.
	float envelope = smoothstep(0.02, 0.22, p.y) * (1.0 - smoothstep(0.75, 1.0, p.y));
	float blade = stroke(abs(p.x), mix(0.065, 0.008, p.y)) * envelope;
	float halo = exp(-abs(p.x) * 13.0) * envelope * 0.35;
	float chevrons = 0.0;
	for (int i = 0; i < 3; i++) {
		float tip = 0.38 + float(i) * 0.20 + progress * 0.10;
		float distance_value = abs(p.y - tip + abs(p.x) * 0.37);
		float wings = 1.0 - smoothstep(0.50, 0.70, abs(p.x));
		chevrons += stroke(distance_value, 0.021) * wings * (1.0 - float(i) * 0.15);
	}
	float streaks = stroke(abs(abs(p.x) - 0.78), 0.009) * envelope * 0.35;
	float light = blade + chevrons + streaks + halo;
	ALBEDO = mix(tint, vec3(0.95, 0.97, 1.0), clamp(blade + chevrons * 0.55, 0.0, 0.85));
	ALPHA = clamp(light, 0.0, 1.0) * opacity;
}
