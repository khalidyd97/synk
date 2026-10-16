shader_type canvas_item;

// Lobby hero art: the cover as a faded photo that dissolves into the background on the
// right and darkens toward the bottom so the track details stay readable on top of it.
uniform vec2 rect_size = vec2(1.0);
uniform float desaturate = 0.25;

varying vec2 local;

void vertex() {
	// Rect-local 0..1 position; UV only spans the cropped part of the texture.
	local = VERTEX / rect_size;
}

void fragment() {
	vec4 art = texture(TEXTURE, UV) * COLOR;
	float lum = dot(art.rgb, vec3(0.3, 0.55, 0.15));
	vec3 color = mix(art.rgb, vec3(lum), desaturate);
	color *= mix(1.0, 0.28, smoothstep(0.32, 0.95, local.y));
	float fade = 1.0 - smoothstep(0.38, 1.0, local.x);
	fade *= smoothstep(0.0, 0.10, local.y) * (1.0 - smoothstep(0.88, 1.0, local.y));
	COLOR = vec4(color, art.a * fade * 0.92);
}
