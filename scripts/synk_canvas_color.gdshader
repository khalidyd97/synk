shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
uniform vec4 color : source_color=vec4(1.0);
#include "res://scripts/ssrg_warp.gdshaderinc"
varying float canvas_z;
void vertex(){VERTEX=ssrg_warp_canvas(VERTEX,MODEL_MATRIX);canvas_z=(MODEL_MATRIX*vec4(VERTEX,1.0)).z;}
// Nothing draws past the point where notes are revealed (the rail top in the recorder).
void fragment(){if(ssrg_warp.x>0.5 && canvas_z<ssrg_reveal_z())discard;ALBEDO=color.rgb;ALPHA=color.a;}
