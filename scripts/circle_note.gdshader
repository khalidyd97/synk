shader_type spatial;
render_mode unshaded, blend_mix, depth_prepass_alpha, cull_disabled, fog_disabled;

#include "res://scripts/highway_clip.gdshaderinc"

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
	rail_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	world_z = (MODEL_MATRIX * vec4(VERTEX, 1.0)).z;
}

void fragment() {
	if(outside_rails(INV_VIEW_MATRIX[3].xyz)) discard;
	if (world_z > clip_z) discard;
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float disc = 1.0 - smoothstep(0.790, 0.815, r);
	float halo = exp(-pow((r - 0.81) / 0.12, 2.0)) * (1.0 - disc);
	// A filled enamel face with a broad bevel, rather than stacked luminous rings.
	vec3 pigment = recolor ? tint : vec3(0.12, 0.32, 1.0);
	float front = 1.0 - smoothstep(-0.65, 0.55, p.y);
	vec3 color = pigment * (0.56 + 0.24 * front);
	float bevel = smoothstep(0.59, 0.72, r) * (1.0 - smoothstep(0.75, 0.80, r));
	color = mix(color, pigment * 1.12, bevel * 0.78);
	float rim = exp(-pow((r - 0.769) / 0.017, 2.0));
	color = mix(color, vec3(0.90, 0.97, 1.0), rim * 0.90);
	// A restrained broad reflection gives the filled center a solid surface.
	float gloss = exp(-pow((p.x + p.y * 0.28) / 0.66, 2.0) - pow((p.y + 0.28) / 0.32, 2.0));
	color += vec3(0.16, 0.19, 0.23) * gloss;
	color *= 1.0 + glow_pulse * 0.35 * (0.5 + 0.5 * sin(animation_time * 3.0));
	vec3 final_color = mix(pigment, color, disc);
	float gray = dot(final_color, vec3(0.299, 0.587, 0.114));
	ALBEDO = mix(final_color, vec3(gray * 0.52), desaturate);
	ALPHA = (disc + halo * 0.12) * opacity * ghost_fade * smoothstep(-60.0, -40.0, world_z);
}
