shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

// One half of a flick note cut in two by the slice: the flick frame artwork, kept only on
// one side of a straight cut through the disc, with a hot glowing edge along the cut.
uniform sampler2D artwork : source_color, filter_linear_mipmap, repeat_disable;
// Where the cut crosses the art (UV), and its direction in UV space (y runs down).
uniform vec2 cut_point = vec2(0.5, 0.72);
uniform float cut_angle = -0.44;
// +1 keeps the half below the cut, -1 the half above it.
uniform float side = 1.0;
uniform float opacity = 1.0;
// How hot the freshly cut edge glows (1 at the cut, cooling to 0).
uniform float heat = 1.0;
uniform vec3 edge_color : source_color = vec3(1.0, 0.8, 0.9);
// Player setting: how bright notes are, so the halves match the note they replace.
global uniform float synk_note_brightness;

void fragment() {
	vec2 n = vec2(-sin(cut_angle), cos(cut_angle));
	float s = dot(UV - cut_point, n) * side;
	if (s < 0.0) discard;
	vec4 art = texture(artwork, UV);
	float edge = clamp(exp(-s * 45.0) * heat * 1.4, 0.0, 1.0);
	ALBEDO = mix(art.rgb * synk_note_brightness, edge_color, edge);
	ALPHA = art.a * opacity;
}
