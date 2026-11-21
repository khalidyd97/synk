
#include "res://scripts/highway_clip.gdshaderinc"

uniform vec3 tint : source_color = vec3(1.0, 0.25, 0.85);
uniform float ghost_fade = 1.0;
uniform float desaturate = 0.0;

float segment_distance(vec2 p, vec2 a, vec2 b) {
    vec2 edge = b-a;
    return length(p-a-edge*clamp(dot(p-a,edge)/dot(edge,edge),0.0,1.0));
}

#include "res://scripts/ssrg_warp.gdshaderinc"
varying float centre_z;
void vertex(){centre_z=MODEL_MATRIX[3].z; VERTEX=ssrg_warp_rigid(VERTEX,MODEL_MATRIX); rail_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}

// Player setting: how bright notes and their trails are (Settings > Visuals > Notes).
global uniform float synk_note_brightness;
uniform bool note_brightness_applies = true;
void fragment() {
	if(outside_rails(INV_VIEW_MATRIX[3].xyz)) discard;
    vec2 p = (UV-vec2(0.5))*vec2(3.22,1.6);
    float d = min(segment_distance(p,vec2(-0.72,0.44),vec2(0.0,-0.44)),
                  segment_distance(p,vec2(0.0,-0.44),vec2(0.72,0.44)));
    float core = 1.0-smoothstep(0.085,0.13,d);
    float rim = 1.0-smoothstep(0.18,0.24,d);
    // A tight bright glow around the chevron plus a wider soft halo for a clean white bloom.
    float glow = exp(-d*d*45.0)*0.55 + exp(-d*d*10.0)*0.32;
    vec3 color = mix(tint,vec3(1.0),core);
    float gray = dot(color,vec3(0.299,0.587,0.114));
    ALBEDO = mix(color,vec3(gray*0.52),desaturate);
    ALPHA = clamp(rim+glow,0.0,1.0)*ghost_fade*ssrg_reveal(centre_z);
	if(note_brightness_applies) ALBEDO*=synk_note_brightness;
}
