shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
// Recorder beat grid: a line across the track at every beat, brighter on each bar (4 beats),
// scrolling with the notes. On the SKD highway recorded notes travel up the track
// (z = (time - now) * speed), so the grid runs the same way and each line sits exactly
// where a note played on that beat sits.
uniform float now = 0.0;
uniform float speed = 10.0;
uniform float bpm = 120.0;
uniform float offset = 0.0;
uniform bool flow_up = false;
uniform vec4 beat_color : source_color = vec4(0.62, 0.78, 1.0, 0.22);
uniform vec4 bar_color : source_color = vec4(1.0, 0.85, 0.45, 0.55);
varying float world_z;
#include "res://scripts/ssrg_warp.gdshaderinc"
void vertex() { world_z = (MODEL_MATRIX * vec4(VERTEX, 1.0)).z; VERTEX = ssrg_warp_canvas(VERTEX, MODEL_MATRIX); }
void fragment() {
	float t = flow_up ? now + world_z / speed : now - world_z / speed;
	float beats = (t - offset) * bpm / 60.0;
	// Line thickness in beats, so lines keep a steady on-screen weight as they recede.
	float width = fwidth(beats) * 1.4;
	float beat_line = 1.0 - smoothstep(0.0, width, abs(fract(beats + 0.5) - 0.5));
	float bars = beats / 4.0;
	float bar_line = 1.0 - smoothstep(0.0, width * 0.5, abs(fract(bars + 0.5) - 0.5));
	vec4 c = mix(beat_color * beat_line, bar_color, bar_line);
	ALBEDO = c.rgb;
	float far = ssrg_warp.x > 0.5 ? ssrg_reveal(world_z) : smoothstep(-60.0, -45.0, world_z);
	ALPHA = max(beat_color.a * beat_line, bar_color.a * bar_line) * far;
}
