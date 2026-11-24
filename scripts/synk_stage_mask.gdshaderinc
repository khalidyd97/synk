// Shared by the SYNK stages: keeps every stage's animation out from under the highway.
// Each rail is a line on screen from its far end (xy) to its near end (zw), set by
// synk_backdrop.gd from the real rail positions. Between the two rails the stage is plain
// dark, so nothing moves beneath the see-through road.
uniform vec4 road_left = vec4(0.48, 0.1, 0.0, 1.0);
uniform vec4 road_right = vec4(0.52, 0.1, 1.0, 1.0);
const vec3 ROAD_INK = vec3(0.022, 0.017, 0.035);

// 1 outside the highway, 0 under it.
float road_mask(vec2 uv) {
	float t = (uv.y - road_left.y) / max(0.001, road_left.w - road_left.y);
	if (t < 0.0) return 1.0;
	float left = mix(road_left.x, road_left.z, t);
	float right = mix(road_right.x, road_right.z, t);
	float inside = smoothstep(left - 0.003, left + 0.003, uv.x) * smoothstep(right + 0.003, right - 0.003, uv.x);
	return 1.0 - inside;
}
