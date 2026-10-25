shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
// Recorder beat grid: a line across the track at every beat, brighter on each bar (4 beats),
// scrolling with the notes. Track z = (now - time) * speed, so time = now - z / speed.
uniform float now = 0.0;
uniform float speed = 10.0;
uniform float bpm = 120.0;
uniform float offset = 0.0;
uniform vec4 beat_color : source_color = vec4(0.62, 0.78, 1.0, 0.22);
uniform vec4 bar_color : source_color = vec4(1.0, 0.85, 0.45, 0.55);
varying float world_z;
void vertex() { world_z = (MODEL_MATRIX * vec4(VERTEX, 1.0)).z; }
void fragment() {
	float t = now - world_z / speed;
	float beats = (t - offset) * bpm / 60.0;
	// Line thickness in beats, so lines keep a steady on-screen weight as they recede.
	float width = fwidth(beats) * 1.4;
	float beat_line = 1.0 - smoothstep(0.0, width, abs(fract(beats + 0.5) - 0.5));
	float bars = beats / 4.0;
	float bar_line = 1.0 - smoothstep(0.0, width * 0.5, abs(fract(bars + 0.5) - 0.5));
	vec4 c = mix(beat_color * beat_line, bar_color, bar_line);
	ALBEDO = c.rgb;
	ALPHA = max(beat_color.a * beat_line, bar_color.a * bar_line) * smoothstep(-60.0, -45.0, world_z);
}
