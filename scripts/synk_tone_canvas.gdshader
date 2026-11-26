shader_type canvas_item;
// SYNK mode adaptive colours for 2D art (the pause button): its gold turned to the song's colour.
uniform vec3 tone = vec3(0.0, 1.0, 1.0);
#include "res://scripts/synk_tone.gdshaderinc"
void fragment(){
    // COLOR already holds the texture's colour here.
    COLOR=vec4(synk_turn(COLOR.rgb,tone),COLOR.a);
}
