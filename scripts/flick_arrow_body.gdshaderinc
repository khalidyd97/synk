
#include "res://scripts/highway_clip.gdshaderinc"

uniform vec3 tint : source_color = vec3(1.0, 0.25, 0.85);
uniform float ghost_fade = 1.0;
uniform float desaturate = 0.0;
// Brightness throb (0..1) set per frame so the arrow pulses, catching the eye.
uniform float pulse = 0.0;

float segment_distance(vec2 p,vec2 a,vec2 b){
    vec2 edge=b-a;
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
    vec2 p=(UV-vec2(.5))*vec2(2.0,1.0);
    // A single shallow V points toward the far end of the highway. Its broad
    // shoulders remain readable, while the slim stroke keeps it elegant.
    float d=min(segment_distance(p,vec2(-.72,.27),vec2(0.0,-.27)),
                segment_distance(p,vec2(0.0,-.27),vec2(.72,.27)));
    float core=1.0-smoothstep(.075,.105,d);
    float outline=1.0-smoothstep(.135,.175,d);
    float glow=exp(-d*d*24.0)*(.12+.10*pulse);
    vec3 dark = vec3(0.0,0.0,0.015);
    vec3 color = mix(dark,tint,core);
    float gray = dot(color,vec3(0.299,0.587,0.114));
    ALBEDO = mix(color,vec3(gray*0.52),desaturate);
    float solid=max(outline,core);
    float a=max(solid,glow*(1.0-outline));
    ALPHA = clamp(a,0.0,1.0)*ghost_fade*ssrg_reveal(centre_z);
	if(note_brightness_applies) ALBEDO*=synk_note_brightness;
}
