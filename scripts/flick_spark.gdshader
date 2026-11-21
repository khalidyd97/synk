shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

// A single soft round spark for the flick hit splash. Many of these are flung upward from
// the judgment bar (tall, narrow) to read as an explosive burst in the flick's up direction.
uniform vec3 tint : source_color = vec3(1.0);
uniform float opacity = 1.0;

void fragment() {
	float d = distance(UV, vec2(0.5));
	float core = smoothstep(0.5, 0.0, d);   // soft falloff to the edge
	ALBEDO = tint;
	ALPHA = core * core * opacity;
}
