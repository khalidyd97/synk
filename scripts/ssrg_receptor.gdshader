shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
uniform float progress : hint_range(0.0,1.0) = 0.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform sampler2D artwork : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 tone = vec3(0.0, 1.0, 1.0);   // SYNK mode adaptive colours
#include "res://scripts/synk_tone.gdshaderinc"
#include "res://scripts/synk_note_shape.gdshaderinc"
void fragment(){
    vec4 art=textureGrad(artwork,synk_shape_uv(UV),dFdx(UV),dFdy(UV));
    ALBEDO=synk_turn(art.rgb,tone)*tint.rgb;
    ALPHA=art.a*progress*tint.a;
}
