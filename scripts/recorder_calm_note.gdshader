shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
// The recorder's note on the SKD highway: a flat, matte disc lying on the track, coloured by
// note type. No gloss, halo or pulse, so a busy take stays easy to read while you play.
uniform vec4 tint : source_color = vec4(0.55, 0.78, 0.92, 1.0);
uniform float ghost_fade = 1.0;
uniform float desaturate = 0.0;
uniform float clip_z = 1000.0;
varying float world_z;
varying float centre_z;
#include "res://scripts/ssrg_warp.gdshaderinc"
void vertex(){ world_z=(MODEL_MATRIX*vec4(VERTEX,1.0)).z; centre_z=MODEL_MATRIX[3].z; VERTEX=ssrg_warp_rigid(VERTEX,MODEL_MATRIX); }
global uniform float synk_note_brightness;
// The recorder's notes take the note shape chosen for SYNK mode.
#include "res://scripts/synk_note_shape.gdshaderinc"
void fragment(){
    if((ssrg_warp.x>0.5?centre_z:world_z)>clip_z) discard;
    // The note shape filling the quad (the quad already has the disc's foreshortened shape).
    vec2 p=(UV-0.5)*2.0;
    float r=synk_shape_size(p);
    float edge=fwidth(r)*1.2+0.002;
    float body=1.0-smoothstep(1.0-edge,1.0,r);
    // A thin lighter rim keeps the edge readable on the dark track; a faint lighter top
    // stops the face looking dead flat.
    float outline=smoothstep(0.78,0.86,r);
    float top=(1.0-smoothstep(-0.7,0.2,p.y))*(1.0-outline)*0.14;
    vec3 colour=mix(tint.rgb*0.88,vec3(0.957,0.945,0.918),top);
    colour=mix(colour,mix(tint.rgb,vec3(0.957,0.945,0.918),0.45),outline);
    float gray=dot(colour,vec3(0.299,0.587,0.114));
    ALBEDO=mix(colour,vec3(gray*0.52),desaturate)*synk_note_brightness;
    ALPHA=body*0.94*tint.a*ghost_fade*smoothstep(-60.0,-55.0,world_z)*ssrg_reveal(centre_z);
}
