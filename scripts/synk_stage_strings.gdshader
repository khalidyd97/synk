shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

// SYNK stage "Strings": the highway is a giant instrument. Eight tall strings stand in a
// row along each rail, like a harp, running back to the horizon. A note hit plucks the
// strings on its side (`pluck`, set by synk_backdrop.gd): they swing as standing waves in
// the note's colour (`tint`) and ring out; the pluck travels up the row to the far strings.
uniform vec2 vanish = vec2(0.5, 0.1);
uniform float aspect = 1.7778;
uniform float beat = 0.0;
uniform float energy = 0.0;
uniform float brightness = 1.0;
uniform float pluck[16];                // 0..8 left row (near to far), 8..16 right row
uniform vec3 tint[16] : source_color;
global uniform float synk_time;

const vec3 IDLE = vec3(0.50, 0.44, 0.50);
const vec3 CREAM = vec3(1.0, 0.945, 0.86);

void fragment() {
	float kick = exp(-beat * 5.0);
	float below = UV.y - vanish.y;
	vec3 col = mix(vec3(0.03, 0.022, 0.05), vec3(0.085, 0.04, 0.10), smoothstep(0.0, 1.0, UV.y));
	col += vec3(1.0, 0.4, 0.25) * exp(-abs(below) * 40.0) * (0.07 + 0.05 * kick);
	for (int k = 0; k < 16; k++) {
		float side = k < 8 ? -1.0 : 1.0;
		float j = float(k < 8 ? k : k - 8);
		float z = 1.15 + j * 0.75;
		float s = 0.78 / z;                  // how far below the horizon this string stands
		float foot_y = vanish.y + s;
		float foot_x = vanish.x + side * (0.60 * s + 0.035);
		float height = s * 1.45 + 0.06;
		float along = (foot_y - UV.y) / height;   // 0 at the foot, 1 at the top
		if (along < 0.0 || along > 1.0) continue;
		float power = pluck[k];
		// Standing wave: fixed at both ends, widest in the middle.
		float belly = sin(3.14159 * along);
		float swing = (power * 0.03 + 0.0025 * kick * (1.0 + energy)) * (0.35 + s);
		float x = foot_x + swing * belly * sin(synk_time * (46.0 - j * 3.5) + float(k) * 1.7);
		float d = abs(UV.x - x) * aspect;
		float width = 0.0009 + 0.0038 * s;
		float core = exp(-pow(d / width, 2.0));
		float halo = exp(-d / (width * 7.0)) * (0.08 + 0.5 * power);
		// A plucked string blurs into a soft band as wide as its swing.
		float band = smoothstep(swing * belly * aspect + width, 0.0, abs(UV.x - foot_x) * aspect) * power * 0.22;
		vec3 colour = mix(IDLE, tint[k], clamp(power * 1.6, 0.0, 1.0));
		float depth = mix(1.0, 0.45, j / 7.0);       // far strings are dimmer
		float ends = smoothstep(0.0, 0.03, along) * smoothstep(1.0, 0.85, along);
		col += colour * (core * (0.35 + 1.3 * power) + halo + band) * depth * ends;
		col += CREAM * core * power * 0.5 * depth * ends;
		// A small bright peg where the string meets the floor.
		float peg = length((UV - vec2(foot_x, foot_y)) * vec2(aspect, 1.0));
		col += colour * exp(-peg / (0.004 + 0.012 * s)) * (0.35 + power) * depth;
	}
	ALBEDO = col * brightness;
	ALPHA = 1.0;
}
