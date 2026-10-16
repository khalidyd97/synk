shader_type canvas_item;

// Draws a TextureRect's image clipped to a rounded rectangle.
uniform vec2 rect_size = vec2(100.0, 100.0);
uniform float radius = 12.0;

void fragment() {
	vec2 p = UV * rect_size;
	vec2 inner = clamp(p, vec2(radius), rect_size - vec2(radius));
	float distance_out = length(p - inner) - radius;
	float mask = 1.0 - smoothstep(-1.0, 1.0, distance_out);
	COLOR = texture(TEXTURE, UV) * COLOR;
	COLOR.a *= mask;
}
