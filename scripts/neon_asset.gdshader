shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

#include "res://scripts/highway_clip.gdshaderinc"

uniform sampler2D artwork : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0);
uniform float opacity = 1.0;
uniform bool recolor = false;
uniform bool rail_warp = false;
uniform float animation_time = 0.0;
uniform float motion = 0.0;
uniform float glow_pulse = 0.0;
uniform float desaturate = 0.0;
uniform float ghost_fade = 1.0;
// While a hold or slide is held, anything past this world z (the judgment bar) is hidden.
uniform float clip_z = 1000.0;
// Extends art that is cut off at its bottom edge: the quad is this much taller than the art,
// and the extra part shows a mirrored copy that fades out (used by the hit flashes).
uniform float mirror_extra = 0.0;
uniform vec3 tint : source_color = vec3(0.6, 0.2, 1.0);

// Fades toward the far end of the highway (world z -60), matching track_surface.gdshader.
varying float world_z;

void vertex() {
	rail_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	world_z = (MODEL_MATRIX * vec4(VERTEX, 1.0)).z;
}

void fragment() {
	if(outside_rails(INV_VIEW_MATRIX[3].xyz)) discard;
	if (world_z > clip_z) discard;
	vec2 artwork_uv = UV;
	float mirror_fade = 1.0;
	if (mirror_extra > 0.0) {
		artwork_uv.y = UV.y * (1.0 + mirror_extra);
		if (artwork_uv.y > 1.0) {
			float below = (artwork_uv.y - 1.0) / mirror_extra;
			artwork_uv.y = 1.0 - (artwork_uv.y - 1.0);
			mirror_fade = pow(1.0 - smoothstep(0.0, 1.0, below), 2.5) * 0.85;
		}
	}
	if (rail_warp) {
		artwork_uv.x = 0.5 + (UV.x - 0.5) * mix(0.27, 0.94, UV.y);
	}
	vec4 sample_color = texture(artwork, region.xy + artwork_uv * region.zw);
	float peak = max(sample_color.r, max(sample_color.g, sample_color.b));
	float white = min(sample_color.r, min(sample_color.g, sample_color.b)) / max(peak, 0.001);
	vec3 color = recolor ? mix(tint, vec3(1.0), white * white) * peak : sample_color.rgb;
	ALBEDO = color;
	// Light travels through the artwork without moving note geometry or endpoints.
	float sweep = pow(max(0.0, sin(UV.y * 25.0 + animation_time * 7.0)), 8.0);
	ALBEDO *= 1.0 + motion * (0.12 * sin(animation_time * 5.0) + 0.38 * sweep);
	// A soft breathing glow, kept narrow so adjacent notes stay distinct.
	float pulse = 0.5 + 0.5 * sin(animation_time * 3.0);
	ALBEDO *= 1.0 + glow_pulse * pulse;
	float gray = dot(ALBEDO, vec3(0.299, 0.587, 0.114));
	ALBEDO = mix(ALBEDO, vec3(gray * 0.52), desaturate);
	ALPHA = sample_color.a * mirror_fade * smoothstep(0.025, 0.13, peak) * opacity * ghost_fade * smoothstep(-60.0, -40.0, world_z);
}
