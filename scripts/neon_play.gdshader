shader_type canvas_item;
render_mode blend_mix;

uniform float hover_amount = 0.0;
uniform float press_amount = 0.0;
uniform float disabled_amount = 0.0;

void fragment() {
	// The supplied reference includes a dark screenshot margin around the button.
	vec2 source_uv = vec2(11.0 / 249.0, 7.0 / 88.0) + UV * vec2(226.0 / 249.0, 59.0 / 88.0);
	vec4 art = texture(TEXTURE, source_uv);
	float peak = max(art.r, max(art.g, art.b));
	// Keys out the navy backdrop (about 9-20% bright) so the plate floats over the lobby.
	float silhouette = smoothstep(0.17, 0.34, peak);
	float breath = 0.94 + 0.08 * sin(TIME * 2.3);
	float sweep_x = fract(TIME * 0.23) * 1.4 - 0.20;
	float sweep = exp(-pow((UV.x - sweep_x) / 0.055, 2.0));
	float left_rings = exp(-pow((UV.x - 0.23 - 0.018 * sin(TIME * 2.7)) / 0.075, 2.0));
	vec3 color = art.rgb * (breath + hover_amount * 0.30 + press_amount * 0.36);
	color += vec3(0.16, 0.05, 0.30) * sweep * silhouette * (0.50 + hover_amount * 0.45);
	color += vec3(0.07, 0.01, 0.20) * left_rings * silhouette * (0.5 + 0.5 * sin(TIME * 3.5));
	color = mix(color, color * 0.38, disabled_amount);
	COLOR = vec4(color, art.a * silhouette);
}
