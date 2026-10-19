shader_type canvas_item;

// Frosted glass: blurs whatever is drawn behind this rectangle and clips it to rounded corners.
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform vec2 rect_size = vec2(100.0);
uniform float radius = 28.0;
uniform float blur = 3.5;
uniform vec4 tint : source_color = vec4(0.03, 0.03, 0.03, 0.45);

void fragment() {
	vec2 p = UV * rect_size;
	vec2 inner = clamp(p, vec2(radius), rect_size - vec2(radius));
	float mask = 1.0 - smoothstep(-1.0, 1.0, length(p - inner) - radius);
	vec3 blurred = textureLod(screen, SCREEN_UV, blur).rgb;
	COLOR = vec4(mix(blurred, tint.rgb, tint.a), mask);
}
