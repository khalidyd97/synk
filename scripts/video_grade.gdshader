shader_type canvas_item;

// Live colour grade for background footage: rotates hue (in turns), adjusts saturation and
// brightness. Rotation happens in YIQ space, which keeps the footage's brightness intact.
uniform float hue_shift = 0.0;
uniform float saturation = 1.0;
uniform float brightness = 1.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	mat3 to_yiq = mat3(vec3(0.299, 0.596, 0.211), vec3(0.587, -0.274, -0.523), vec3(0.114, -0.322, 0.312));
	mat3 to_rgb = mat3(vec3(1.0, 1.0, 1.0), vec3(0.956, -0.272, -1.106), vec3(0.621, -0.647, 1.703));
	vec3 yiq = to_yiq * c.rgb;
	float a = hue_shift * 6.28318530718;
	yiq.yz = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * yiq.yz * saturation;
	COLOR = vec4(clamp(to_rgb * yiq * brightness, 0.0, 1.0), c.a);
}
