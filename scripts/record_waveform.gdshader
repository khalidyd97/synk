shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
// Recorder waveform lane beside the highway: the song's loudness as bars, scrolling with the
// notes. peaks holds one value per sample (sample_rate per second) in its red channel.
uniform sampler2D peaks : filter_nearest, repeat_disable;   // grid of ROW samples per row
uniform float sample_count = 1.0;
uniform float sample_rate = 40.0;
uniform float now = 0.0;
uniform float speed = 10.0;
uniform vec4 tint : source_color = vec4(0.42, 0.85, 1.0, 1.0);
varying float world_z;
void vertex() { world_z = (MODEL_MATRIX * vec4(VERTEX, 1.0)).z; }
void fragment() {
	float t = now - world_z / speed;
	float index = t * sample_rate;
	float level = 0.0;
	if (index >= 0.0 && index < sample_count) {
		ivec2 grid = textureSize(peaks, 0);
		int i = int(index);
		level = texelFetch(peaks, ivec2(i % grid.x, i / grid.x), 0).r;
	}
	// Bars grow out from the lane's centre line; quiet parts stay a thin line.
	float half_width = abs(UV.x - 0.5) * 2.0;
	float bar = 1.0 - smoothstep(level * 0.95, level * 0.95 + 0.04, half_width);
	float now_glow = exp(-abs(world_z) * 0.8) * 0.6;   // brighter right at the judgement line
	ALBEDO = mix(tint.rgb, vec3(1.0), now_glow);
	ALPHA = bar * (0.55 + now_glow) * smoothstep(-60.0, -45.0, world_z);
}
