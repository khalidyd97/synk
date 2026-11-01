shader_type canvas_item;

// Draws a TextureRect's image clipped to a rounded rectangle.
uniform vec2 rect_size = vec2(100.0, 100.0);
uniform float radius = 12.0;
uniform float hit_glow = 0.0;
uniform float glare_progress = 1.0;

void fragment() {
	vec2 p = UV * rect_size;
	vec2 inner = clamp(p, vec2(radius), rect_size - vec2(radius));
	float distance_out = length(p - inner) - radius;
	float mask = 1.0 - smoothstep(-1.0, 1.0, distance_out);
	COLOR = texture(TEXTURE, UV) * COLOR;
	float sweep = exp(-pow((UV.x + UV.y * 0.35 - mix(-0.3, 1.7, glare_progress)) / 0.12, 2.0));
	COLOR.rgb += vec3(hit_glow * (0.07 + sweep * 0.34));
	COLOR.a *= mask;
}
