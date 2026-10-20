shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

// The current song's cover on a camera-facing plane far behind the highway. It fills the
// screen width, drifts slowly and kicks softly on the beat.
uniform sampler2D cover : source_color, filter_linear;
uniform vec3 tint : source_color = vec3(1.0);
uniform float strength = 0.0;
uniform float brightness = 1.0;
uniform float screen_aspect = 1.7778;
// Width / height of the backdrop image: square album art or a wide gameplay background.
uniform float image_aspect = 1.0;
// No artwork: draw solid black.
uniform bool plain = false;
uniform float beat = 0.0;
// One global clock for every highway shader (set once per frame by highway_3d.gd).
global uniform float synk_time;
#define animation_time synk_time
uniform vec3 rail_glow_left : source_color = vec3(0.4,0.7,1.0);
uniform vec3 rail_glow_right : source_color = vec3(0.8,0.4,1.0);
uniform float rail_glow_opacity : hint_range(0.0,0.3) = 0.12;
uniform float glow_beat = 0.0;
// Projected rail x at the top/bottom of the screen; follows aspect ratio and camera angle.
uniform vec2 glow_left_rail = vec2(0.45,-0.05);
uniform vec2 glow_right_rail = vec2(0.55,1.05);

void fragment() {
	float zoom = 1.06 + 0.03 * sin(animation_time * 0.11);
	// Cover the screen without stretching; square art sits slightly high, as before.
	vec2 fit = image_aspect > screen_aspect ? vec2(screen_aspect / image_aspect, 1.0) : vec2(1.0, image_aspect / screen_aspect);
	float center_y = fit.y < 0.999 ? 0.42 : 0.5;
	vec2 uv = vec2((UV.x - 0.5) * fit.x / zoom + 0.5, (UV.y - center_y) * fit.y / zoom + 0.5);
	vec3 art = texture(cover, uv).rgb * tint;
	float lum = dot(art, vec3(0.3, 0.55, 0.15));
	// Evenly dimmed: no edge fade or glow band, the cover kept behind the notes but readable.
	art = mix(art, vec3(lum), 0.22) * (0.3 + 0.06 * beat);
	// Reference: a broad ceiling of colored haze that falls down the outer sides.
	// Its soft beat swell never flashes; the lane surface remains dark and readable.
	float left_x = mix(glow_left_rail.x,glow_left_rail.y,UV.y);
	float right_x = mix(glow_right_rail.x,glow_right_rail.y,UV.y);
	float inside_track = smoothstep(left_x-0.025,left_x+0.025,UV.x)
		* (1.0-smoothstep(right_x-0.025,right_x+0.025,UV.x));
	float top = exp(-pow(UV.y/0.48,1.6));
	float outer = pow(abs(UV.x-0.5)*2.0,1.5);
	float side = outer*(1.0-smoothstep(0.05,1.0,UV.y))*0.38;
	float edge_halo = exp(-pow((UV.x-left_x)/0.075,2.0))
		+ exp(-pow((UV.x-right_x)/0.075,2.0));
	float haze = (top+side+edge_halo*0.16*(1.0-UV.y))*mix(1.0,0.12,inside_track);
	vec3 wash_color = mix(rail_glow_left,rail_glow_right,smoothstep(0.15,0.85,UV.x));
	vec3 wash = wash_color*haze*rail_glow_opacity*(1.25+glow_beat*0.45);
	ALBEDO = plain ? vec3(0.0) : (art+wash) * brightness;
	ALPHA = strength;
}
