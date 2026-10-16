shader_type canvas_item;
render_mode blend_mix;

// Draws the art shrunk inside a padded quad and fills the padding with a soft halo
// built from the art's blurred alpha. `pad` is the UV margin on each side; `reach_scale`
// keeps the halo equally wide on every side of non-square art.
uniform vec4 glow_color : source_color = vec4(0.72, 0.45, 1.0, 1.0);
uniform float pad = 0.1;
uniform vec2 reach_scale = vec2(1.0, 1.0);
uniform float strength = 0.6;
uniform float boost = 0.0;
// Optional top-to-bottom recolor of the art (the combo digits use the song's cover colors).
uniform bool use_gradient = false;
// 1.0 turns the art into soft silver so it sits on top of any color scheme.
uniform float monochrome = 0.0;
uniform vec3 gradient_top : source_color = vec3(0.22, 0.73, 1.0);
uniform vec3 gradient_middle : source_color = vec3(0.64, 0.42, 1.0);
uniform vec3 gradient_bottom : source_color = vec3(1.0, 0.83, 0.28);

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

float inside(vec2 uv) {
	vec2 edges = step(vec2(0.0), uv) * step(uv, vec2(1.0));
	return edges.x * edges.y;
}

void fragment() {
	float scale = 1.0 - 2.0 * pad;
	vec2 uv = (UV - pad) / scale;
	vec2 reach = pad / scale * reach_scale * 0.85;
	vec4 art = texture(TEXTURE, uv) * inside(uv);
	if (use_gradient) {
		float t = clamp(uv.y, 0.0, 1.0);
		vec3 ramp = t < 0.5 ? mix(gradient_top, gradient_middle, t * 2.0) : mix(gradient_middle, gradient_bottom, t * 2.0 - 1.0);
		// Keep the art's shading: bright cores stay near white, darker edges take the ramp color.
		float peak = max(art.r, max(art.g, art.b));
		float white = min(art.r, min(art.g, art.b)) / max(peak, 0.001);
		art.rgb = mix(ramp, vec3(1.0), white * white * 0.55) * min(1.0, peak * 1.15);
	}
	float luma = dot(art.rgb, vec3(0.299, 0.587, 0.114));
	art.rgb = mix(art.rgb, vec3(0.86, 0.88, 0.94) * smoothstep(0.05, 0.75, luma), monochrome);
	float glow = 0.0;
	float total = 0.0;
	for (int ring = 1; ring <= 3; ring++) {
		float distance = float(ring) / 3.0;
		float weight = 1.0 - distance * 0.6;
		for (int i = 0; i < 12; i++) {
			float angle = float(i) * 0.5235988 + float(ring) * 0.26;
			vec2 sample_uv = uv + vec2(cos(angle), sin(angle)) * reach * distance;
			glow += texture(TEXTURE, sample_uv).a * inside(sample_uv) * weight;
			total += weight;
		}
	}
	float glow_alpha = clamp(glow / total * strength * (1.0 + boost * 0.8), 0.0, 1.0) * glow_color.a;
	vec3 rgb = mix(glow_color.rgb, art.rgb, art.a);
	float alpha = art.a + glow_alpha * (1.0 - art.a);
	COLOR = vec4(rgb, alpha) * tint;
}
