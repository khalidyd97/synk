shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
// SSRG stage floor: dark tinted glass, a little more opaque near the line, a soft sheen down the
// middle, and fading out toward the far end so the song art shows through behind it.
uniform vec3 glass : source_color = vec3(0.035, 0.04, 0.07);
uniform float opacity = 0.78;
varying float world_z;
void vertex() { world_z = (MODEL_MATRIX * vec4(VERTEX, 1.0)).z; }
void fragment() {
	float depth = clamp(-world_z / 600.0, 0.0, 1.0);
	float sheen = exp(-pow((UV.x - 0.5) * 3.2, 2.0)) * 0.05;
	float edge = smoothstep(0.0, 0.025, UV.x) * smoothstep(0.0, 0.025, 1.0 - UV.x);
	ALBEDO = glass + vec3(sheen);
	ALPHA = opacity * mix(1.0, 0.72, depth) * smoothstep(-1500.0, -900.0, world_z) * edge;
}
