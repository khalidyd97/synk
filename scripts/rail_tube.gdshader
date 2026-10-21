shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_back, fog_disabled;

// A glossy cream rail: a rounded tube lit from above, with a bright specular streak
// along its crown and warm shading where it curves away toward the highway.
uniform vec3 tint : source_color = vec3(1.0, 0.9, 0.75);
// How much of the song's palette colors the cream.
uniform float tint_amount = 0.0;

varying float world_z;
varying vec3 world_normal;

void vertex() {
	world_z = (MODEL_MATRIX * vec4(VERTEX, 1.0)).z;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(world_normal);
	float diffuse = clamp(dot(n, normalize(vec3(0.0, 1.0, 0.45))) * 0.5 + 0.5, 0.0, 1.0);
	vec3 cream = vec3(1.0, 1.0, 1.0);
	vec3 shade = vec3(0.42, 0.44, 0.46);
	float lit = smoothstep(0.2, 0.9, diffuse);
	// A colored rail keeps the same rounded shading: dark flank, bright crown.
	vec3 color = mix(mix(shade, cream, lit), tint * (0.38 + 0.72 * lit), tint_amount);
	float crown = pow(clamp(dot(n, normalize(vec3(0.0, 1.0, 0.25))), 0.0, 1.0), 28.0);
	color += vec3(1.0, 0.98, 0.94) * crown * 0.55;
	ALBEDO = color;
	ALPHA = smoothstep(-61.0, -57.0, world_z);
}
