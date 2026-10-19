shader_type canvas_item;

// Album art as a soft backdrop: a wide two-ring blur plus a slight saturation lift, so the
// cover reads as coloured light rather than a picture.
uniform float radius = 0.06;

void fragment() {
	vec3 sum = texture(TEXTURE, UV).rgb;
	float count = 1.0;
	for (int ring = 1; ring <= 3; ring++) {
		float r = radius * float(ring) / 3.0;
		for (int i = 0; i < 12; i++) {
			float a = float(i) / 12.0 * 6.28318530718 + float(ring) * 0.5;
			sum += texture(TEXTURE, clamp(UV + vec2(cos(a), sin(a)) * r, vec2(0.0), vec2(1.0))).rgb;
			count += 1.0;
		}
	}
	vec3 c = sum / count;
	float l = dot(c, vec3(0.3, 0.59, 0.11));
	COLOR = vec4(mix(vec3(l), c, 1.35), 1.0);
}
