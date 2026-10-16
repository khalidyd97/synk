shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

// Raised neon puck, based on the circular-note reference: saturated center,
// cyan bevel, a narrow white rim, and a soft halo outside the solid face.
// The same miss/hold uniforms as neon_asset.gdshader keep gameplay behavior intact.
uniform vec3 tint : source_color = vec3(0.22, 0.73, 1.0);
uniform bool recolor = true;
uniform float opacity = 1.0;
uniform float animation_time = 0.0;
uniform float motion = 0.0;
uniform float glow_pulse = 0.0;
uniform float desaturate = 0.0;
uniform float ghost_fade = 1.0;
uniform float clip_z = 1000.0;

varying float world_z;

void vertex() {
	world_z = (MODEL_MATRIX * vec4(VERTEX, 1.0)).z;
}

void fragment() {
	if (world_z > clip_z) discard;
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float disc = 1.0 - smoothstep(0.790, 0.815, r);
	float halo = exp(-pow((r - 0.81) / 0.12, 2.0)) * (1.0 - disc);
	float front = 1.0 - smoothstep(-0.65, 0.35, p.y);
	vec3 deep = recolor ? tint * 0.64 : vec3(0.025, 0.22, 0.88);
	vec3 color = mix(deep, tint * 1.10, smoothstep(0.10, 0.78, r) * 0.62 + front * 0.18);
	// Two concentric bevels keep the white band crisp even at the far end of the rail.
	float inner_edge = exp(-pow((r - 0.635) / 0.020, 2.0));
	float cyan_bevel = exp(-pow((r - 0.705) / 0.055, 2.0));
	float white_rim = exp(-pow((r - 0.768) / 0.025, 2.0));
	color = mix(color, tint * 1.65, cyan_bevel * 0.65);
	color = mix(color, vec3(1.0), white_rim * 0.98 + inner_edge * 0.14);
	// Broad specular sweep across the top; it never obscures the colored center.
	float gloss = exp(-pow((p.x + p.y * 0.14) / 0.52, 2.0) - pow((p.y - 0.18) / 0.27, 2.0));
	color += vec3(1.0) * gloss * 0.11;
	float pulse = 0.5 + 0.5 * sin(animation_time * 3.0);
	color *= 1.0 + glow_pulse * pulse;
	vec3 final_color = mix(tint * 1.25, color, disc);
	float gray = dot(final_color, vec3(0.299, 0.587, 0.114));
	ALBEDO = mix(final_color, vec3(gray * 0.52), desaturate);
	ALPHA = (disc + halo * 0.31) * opacity * ghost_fade * smoothstep(-60.0, -40.0, world_z);
}
