shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
// Lumen: SYNK's own hit flash, built the way SKD builds its flash. One camera-facing sprite
// on the judgement line, eleven frames stepped by the same 33 fps clock, the same lifetime,
// sustain re-triggers and lane rule. Only the picture is new:
//   a lens streak along the judgement line, a ring lying flat on the track that opens
//   outward, a short light column rising up the lane, and a few glass shards thrown up
//   (or toward a flick's direction) that fall back.
uniform vec4 tint : source_color = vec4(0.31, 0.82, 1.0, 1.0);
uniform float frame = 0.0;
uniform float opacity = 1.0;
uniform float particles = 1.0;
uniform float seed = 0.0;
// 0 up, 1 right, 2 down, 3 left; below zero for anything that is not a flick.
uniform float direction = -1.0;
// Honour the "Note brightness" setting so this additive flash dims with the notes
// instead of blowing out over the bright song photo.
global uniform float synk_note_brightness;

float hash(float n) { return fract(sin(n * 91.73 + seed * 17.13) * 43758.5453); }

void fragment() {
	// The source sprite is 620 by 372: scale x so circles stay round on screen.
	vec2 p = (UV - 0.5) * 2.0;
	vec2 q = p * vec2(1.6667, 1.0);
	float t = clamp(floor(frame), 0.0, 10.0) / 10.0;
	float fade = pow(1.0 - t, 1.25);

	// Lens streak along the judgement line, and a short cross at its centre.
	float streak = exp(-abs(q.y) * 55.0) * exp(-abs(q.x) * (1.4 + 3.0 * t)) * pow(1.0 - t, 1.6);
	float cross = exp(-abs(q.x) * 70.0) * exp(-abs(q.y) * 5.0) * pow(1.0 - t, 2.4);
	float core = exp(-dot(q * vec2(5.0, 9.0), q * vec2(5.0, 9.0))) * pow(1.0 - t, 1.2);

	// A ring lying on the track: an ellipse squashed by the highway's tilt, opening outward.
	float r = length(q * vec2(1.0, 2.7));
	float radius = 0.22 + 1.05 * sqrt(t);
	float width = 0.05 * (1.0 - 0.45 * t);
	float ring = exp(-pow((r - radius) / width, 2.0)) * fade;
	float trail = exp(-pow((r - radius * 0.68) / (width * 0.7), 2.0)) * fade * 0.35;

	// A column of light rising up the lane from the hit point.
	float column_width = 0.17 * (1.0 - 0.35 * t);
	float top = -(0.2 + 0.75 * sqrt(t));
	float column = exp(-pow(q.x / column_width, 2.0)) * smoothstep(top, 0.0, q.y) * (1.0 - smoothstep(0.0, 0.08, q.y));
	column *= pow(1.0 - t, 1.4) * 0.7;

	// Glass shards: small diamonds thrown up and out, pulled back by gravity.
	float shards = 0.0;
	float count = floor(clamp(particles, 0.0, 1.0) * 9.0);
	vec2 throw_axis = direction < 0.0 ? vec2(0.0, -1.0)
		: (direction < 0.5 ? vec2(0.0, -1.0) : (direction < 1.5 ? vec2(1.0, -0.25) : (direction < 2.5 ? vec2(0.0, 0.6) : vec2(-1.0, -0.25))));
	for (int i = 0; i < 9; i++) {
		float fi = float(i);
		if (fi >= count) break;
		float spread = (hash(fi) - 0.5) * (direction < 0.0 ? 2.4 : 1.1);
		vec2 side = vec2(-throw_axis.y, throw_axis.x);
		vec2 velocity = normalize(throw_axis + side * spread) * (0.75 + hash(fi + 7.0) * 0.6);
		vec2 at = velocity * t * 1.15 + vec2(0.0, 0.85 * t * t);
		vec2 off = q - at;
		// Each diamond points along its own flight.
		vec2 along = normalize(velocity + vec2(0.0, 1.7 * t));
		vec2 local = vec2(dot(off, along), dot(off, vec2(-along.y, along.x)));
		float size = (0.045 + hash(fi + 3.0) * 0.03) * (1.0 - 0.6 * t);
		float diamond = 1.0 - smoothstep(0.85, 1.0, abs(local.x) / (size * 1.9) + abs(local.y) / size);
		shards += diamond + exp(-dot(off, off) / (size * size * 6.0)) * 0.35;
	}
	shards *= pow(1.0 - t, 0.9);

	float halo = exp(-dot(q, q) * 3.2) * 0.45 * fade;
	vec3 colour = tint.rgb * (ring * 1.7 + trail + column * 1.3 + halo + shards * 1.4 + streak * 0.9);
	colour += vec3(1.0) * (core * 2.2 + cross * 1.4 + streak * 0.7 + ring * 0.3 + shards * 0.6);
	float edge = 1.0 - smoothstep(0.85, 1.0, max(abs(p.x), abs(p.y)));
	ALBEDO = colour;
	ALPHA = clamp(ring + trail + column + halo + shards + streak + cross + core, 0.0, 1.0) * edge * opacity * synk_note_brightness;
}
