shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
// Thin flat strip along the track (press lines). UV.x runs across the strip; a soft core
// falloff fading toward the far end. Alpha-blended (not additive) so the hold trail reads
// as a plain line and does not glow/bloom over the background.
uniform vec4 tint : source_color = vec4(0.95, 0.96, 1.0, 1.0);
uniform float strength = 1.0;
uniform float far_fade = 1.0;      // 1: fade with distance; 0: even brightness
// Honour the "Note brightness" setting (its tooltip covers the notes AND their trails),
// which the additive strip otherwise ignored and blew out over the bright song photo.
global uniform float synk_note_brightness;
varying float world_z;
void vertex() { world_z = (MODEL_MATRIX * vec4(VERTEX, 1.0)).z; }
void fragment() {
	float across = abs(UV.x - 0.5) * 2.0;
	float core = exp(-across * across * 18.0) + exp(-across * 4.0) * 0.25;
	float fade = mix(1.0, clamp(1.0 + world_z / 62.0, 0.0, 1.0), far_fade);
	ALBEDO = tint.rgb;
	ALPHA = clamp(core * strength * fade * smoothstep(-62.0, -50.0, world_z), 0.0, 1.0) * synk_note_brightness;
}
