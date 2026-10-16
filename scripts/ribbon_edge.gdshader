shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, fog_disabled;

// Thin bright edges along hold and slide trails. Shares clip_z with neon_asset.gdshader so a
// held trail disappears into the judgment bar, and fades/greys out with missed slides.
uniform vec3 color : source_color = vec3(0.8, 0.7, 1.0);
uniform float clip_z = 1000.0;
uniform float ghost_fade = 1.0;
uniform float desaturate = 0.0;

varying float world_z;

void vertex() {
	world_z = (MODEL_MATRIX * vec4(VERTEX, 1.0)).z;
}

void fragment() {
	if (world_z > clip_z) discard;
	float gray = dot(color, vec3(0.299, 0.587, 0.114));
	ALBEDO = mix(color, vec3(gray * 0.6), desaturate);
	ALPHA = ghost_fade * smoothstep(-60.0, -40.0, world_z);
}
