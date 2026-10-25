shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
// SSRG side rail: a solid white bar with a bevelled edge (bright face, grey shade on one side).
varying float world_z;
void vertex() { world_z = (MODEL_MATRIX * vec4(VERTEX, 1.0)).z; }
void fragment() {
	float across = UV.x;
	vec3 face = mix(vec3(0.62, 0.64, 0.68), vec3(0.98), smoothstep(0.0, 0.45, across));
	face = mix(face, vec3(0.78, 0.8, 0.84), smoothstep(0.75, 1.0, across));
	ALBEDO = face;
	ALPHA = smoothstep(-64.0, -54.0, world_z);
}
