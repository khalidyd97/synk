shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

// SYNK mode's stage: a sea of sound waves either side of the highway, drawn on the
// screen-filling quad behind it (UV is screen space, y down).
//   - Glowing ridgelines lie on a floor that runs to the highway's horizon and flow toward
//     the player in time with the song.
//   - Every ridge is drawn twice, coral and amber, out of step with each other. On each beat
//     the two snap into step and merge into one bright line, then drift apart: they sync.
//   - A swell runs from the horizon to the player once per beat.
//   - Each note hit sends a ripple through the waves from where it landed.
// `energy` (0 calm .. 1 full rave) makes the sea taller and brighter.
uniform vec2 vanish = vec2(0.5, 0.1);   // the highway's far end on screen
uniform float aspect = 1.7778;
uniform float beat = 0.0;               // 0..1 through the current beat
uniform float beats = 0.0;              // beats since the song started (continuous)
uniform float energy = 0.0;
uniform float brightness = 1.0;
// Recent note hits: screen position (xy) and age in seconds (z); z < 0 is unused.
uniform vec3 hits[4];
global uniform float synk_time;

const vec3 INK = vec3(0.03, 0.022, 0.05);
const vec3 DUSK = vec3(0.10, 0.045, 0.14);
const vec3 CORAL = vec3(1.0, 0.36, 0.22);
const vec3 AMBER = vec3(1.0, 0.70, 0.30);
const vec3 CREAM = vec3(1.0, 0.945, 0.86);
const int RIDGES = 11;
const float FLOOR = 0.9;                // screen drop of a ridge one unit away

// Wave height at floor position (x, z); `phase` slides it sideways.
float wave(float x, float z, float phase) {
	return sin(x * 1.1 + z * 0.9 + phase + synk_time * 0.5) * 0.55
		+ sin(x * 2.7 - z * 0.4 - phase * 1.7 - synk_time * 0.8) * 0.3
		+ sin(x * 3.9 + phase * 2.3 + z * 2.1) * 0.08;
}

void fragment() {
	vec2 uv = UV;
	float s = uv.y - vanish.y;              // drop below the horizon
	float dx = (uv.x - vanish.x) * aspect;
	float kick = exp(-beat * 5.0);          // 1 on the beat, decaying through it

	vec3 col = mix(INK, DUSK, smoothstep(0.0, 1.0, uv.y) * 0.7);
	// A thin warm line of light on the horizon.
	col += CORAL * exp(-abs(s) * 45.0) * (0.10 + 0.08 * kick + 0.08 * energy);

	// Ripples from note hits, in screen space.
	float ripple = 0.0;
	for (int i = 0; i < 4; i++) {
		if (hits[i].z < 0.0) continue;
		float age = hits[i].z;
		float d = length((uv - hits[i].xy) * vec2(aspect, 1.0));
		ripple += exp(-pow((d - age * 1.3) / 0.06, 2.0)) * max(0.0, 1.0 - age / 0.7);
	}

	if (s > 0.0) {
		// Keep the road itself clear: the sea lies outside the highway's edges.
		float lateral = abs(uv.x - vanish.x) / s;
		float sea = smoothstep(0.42, 0.62, lateral);
		// The two wave sets are out of step, and lock together on the beat.
		float apart = (1.0 - kick) * (0.7 - 0.2 * energy);
		float amp = (0.055 + 0.045 * kick + 0.05 * energy) * (1.0 + 2.5 * ripple);
		float flow = fract(beats);          // one ridge spacing per beat
		float swell_z = 0.5 + 10.0 * (1.0 - beat) * (1.0 - beat);
		for (int i = 0; i < RIDGES; i++) {
			float z = float(i) + 1.0 - flow;
			float si = FLOOR / z;            // this ridge's drop on screen
			float x = dx / si;               // floor x where this pixel meets the ridge
			float swell = exp(-pow((z - swell_z) / 1.3, 2.0));
			float height = amp * (1.0 + 1.6 * swell) * si * smoothstep(0.5, 1.3, abs(x) * 0.9);
			float width = 0.0012 + 0.0045 * si;
			float a = exp(-pow((s - si + wave(x, z, apart) * height) / width, 2.0));
			float b = exp(-pow((s - si + wave(x, z, -apart) * height) / width, 2.0));
			// Far ridges fade into the horizon; the nearest one fades in as it arrives.
			float fade = smoothstep(float(RIDGES), float(RIDGES) - 6.0, z) * smoothstep(0.0, 0.6, z);
			float glow = (0.45 + 0.5 * energy + 0.9 * swell + 1.2 * ripple) * fade * sea;
			col += (CORAL * a + AMBER * b) * glow;
			// Where the two meet, they burn cream.
			col += CREAM * a * b * glow * 0.8;
		}
	}
	ALBEDO = col * brightness;
	ALPHA = 1.0;
}
