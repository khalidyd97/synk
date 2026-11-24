shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

// SYNK stage "Stars": a dark sky the player fills in. Every note hit lights a star in that
// note's colour and joins it to the last one, so the run draws its own constellation
// (painted into `sky` by synk_constellation.gd). The newest star flares as it appears and
// the whole constellation breathes on the beat.
uniform sampler2D sky : source_color, filter_linear, repeat_disable;
uniform vec2 vanish = vec2(0.5, 0.1);
uniform float aspect = 1.7778;
uniform float beat = 0.0;
uniform float energy = 0.0;
uniform float brightness = 1.0;
uniform vec3 newest = vec3(0.0, 0.0, -1.0);   // newest star: screen position and age
uniform vec3 newest_color : source_color = vec3(1.0);
global uniform float synk_time;
#include "res://scripts/synk_stage_mask.gdshaderinc"

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	// True screen position (0..1, y down), whatever the backdrop quad's size.
	vec2 at = SCREEN_UV;
	float kick = exp(-beat * 5.0);
	// Night sky: deep indigo, a little lighter toward the horizon the highway runs to.
	float horizon = exp(-abs(at.y - vanish.y) * 5.0);
	vec3 col = mix(vec3(0.016, 0.014, 0.04), vec3(0.06, 0.035, 0.11), horizon);
	// Faint dust of distant stars that were always there.
	vec2 grid = at * vec2(aspect, 1.0) * 90.0;
	float dust = step(0.985, hash(floor(grid)));
	vec2 in_cell = fract(grid) - 0.5;
	col += vec3(0.6, 0.62, 0.8) * dust * smoothstep(0.35, 0.0, length(in_cell)) * (0.25 + 0.2 * sin(synk_time * 2.0 + hash(floor(grid) + 5.0) * 30.0));
	// The player's constellation.
	vec4 drawn = texture(sky, at);
	col += drawn.rgb * drawn.a * (0.85 + 0.35 * kick + 0.3 * energy);
	// The newest star flares: a quick ring and glow.
	if (newest.z >= 0.0 && newest.z < 0.6) {
		float d = length((at - newest.xy) * vec2(aspect, 1.0));
		float fade = 1.0 - newest.z / 0.6;
		col += newest_color * exp(-d * 28.0) * fade * 0.9;
		col += newest_color * exp(-pow((d - newest.z * 0.18) / 0.006, 2.0)) * fade * 0.6;
	}
	// Nothing is drawn under the highway.
	ALBEDO = mix(ROAD_INK, col, road_mask(at)) * brightness;
	ALPHA = 1.0;
}
