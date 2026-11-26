shader_type canvas_item;
// Settings previews of SYNK mode's notes: the round note art, bent into the chosen note
// shape the same way the highway does it, with an optional turn of its colour.
#include "res://scripts/synk_note_shape.gdshaderinc"
uniform vec3 tone = vec3(0.0, 1.0, 1.0);
#include "res://scripts/synk_tone.gdshaderinc"
void fragment(){
    vec4 art=textureGrad(TEXTURE,synk_shape_uv(UV),dFdx(UV),dFdy(UV));
    COLOR=vec4(synk_turn(art.rgb,tone),art.a);
}
