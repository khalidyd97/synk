
#include "res://scripts/highway_clip.gdshaderinc"

uniform vec3 tint : source_color = vec3(1.0, 0.25, 0.85);
uniform float ghost_fade = 1.0;
uniform float desaturate = 0.0;
// Brightness throb (0..1) set per frame so the arrow pulses, catching the eye.
uniform float pulse = 0.0;

#include "res://scripts/ssrg_warp.gdshaderinc"
varying float centre_z;
void vertex(){centre_z=MODEL_MATRIX[3].z; VERTEX=ssrg_warp_rigid(VERTEX,MODEL_MATRIX); rail_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}

// Player setting: how bright notes and their trails are (Settings > Visuals > Notes).
global uniform float synk_note_brightness;
uniform bool note_brightness_applies = true;
void fragment() {
	if(outside_rails(INV_VIEW_MATRIX[3].xyz)) discard;
    vec2 p = (UV-vec2(0.5))*vec2(2.0,2.0);
    // One compact filled arrow: a straight stem feeding a broad triangular head.
    // The expanded copy underneath becomes its crisp dark outline.
    float stem_core=(1.0-smoothstep(.17,.20,abs(p.x)))
        *smoothstep(-.14,-.09,p.y)*(1.0-smoothstep(.61,.66,p.y));
    float head_t=clamp((p.y+.66)/.57,0.0,1.0);
    float head_core=smoothstep(-.025,.025,.58*head_t-abs(p.x))
        *smoothstep(-.69,-.64,p.y)*(1.0-smoothstep(-.08,-.03,p.y));
    float core=max(stem_core,head_core);
    float stem_outline=(1.0-smoothstep(.25,.29,abs(p.x)))
        *smoothstep(-.20,-.15,p.y)*(1.0-smoothstep(.66,.71,p.y));
    float outline_t=clamp((p.y+.74)/.69,0.0,1.0);
    float head_outline=smoothstep(-.035,.035,.68*outline_t-abs(p.x))
        *smoothstep(-.78,-.73,p.y)*(1.0-smoothstep(-.06,-.01,p.y));
    float outline=max(stem_outline,head_outline);
    float glow=exp(-pow(max(abs(p.x)-.34,0.0)*3.0,2.0)-pow(p.y*.9,2.0))
        *(.13+.10*pulse);
    vec3 dark = vec3(0.0,0.0,0.015);
    vec3 color = mix(dark,tint,core);
    float gray = dot(color,vec3(0.299,0.587,0.114));
    ALBEDO = mix(color,vec3(gray*0.52),desaturate);
    float solid=max(outline,core);
    float a=max(solid,glow*(1.0-outline));
    ALPHA = clamp(a,0.0,1.0)*ghost_fade*ssrg_reveal(centre_z);
	if(note_brightness_applies) ALBEDO*=synk_note_brightness;
}
