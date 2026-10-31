shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
uniform vec4 color : source_color=vec4(1.0);
#include "res://scripts/ssrg_warp.gdshaderinc"
void vertex(){VERTEX=ssrg_warp_canvas(VERTEX,MODEL_MATRIX);}
void fragment(){ALBEDO=color.rgb;ALPHA=color.a;}
