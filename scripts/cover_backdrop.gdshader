shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

// The current song's cover on a camera-facing plane far behind the highway. It fills the
// screen width, drifts slowly and kicks softly on the beat.
uniform sampler2D cover : source_color, filter_linear;
uniform vec3 tint : source_color = vec3(1.0);
uniform float strength = 0.0;
uniform float brightness = 1.0;
uniform float screen_aspect = 1.7778;
uniform float beat = 0.0;
uniform float animation_time = 0.0;

void fragment() {
	float zoom = 1.06 + 0.03 * sin(animation_time * 0.11);
	vec2 uv = vec2((UV.x - 0.5) / zoom + 0.5, (UV.y - 0.42) / (screen_aspect * zoom) + 0.5);
	vec3 art = texture(cover, uv).rgb * tint;
	float lum = dot(art, vec3(0.3, 0.55, 0.15));
	// Evenly dimmed: no edge fade or glow band, the cover kept behind the notes but readable.
	art = mix(art, vec3(lum), 0.22) * (0.3 + 0.06 * beat);
	ALBEDO = art * brightness;
	ALPHA = strength;
}
