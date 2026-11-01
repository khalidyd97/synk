shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
uniform vec4 base_color:source_color=vec4(.64,.94,1.0,.64);
uniform sampler2D artwork:source_color,filter_linear,repeat_disable;
#include "res://scripts/ssrg_warp.gdshaderinc"
// Flat source-art bar: taper each edge with the same SSRG canvas as the road.
void vertex(){VERTEX=ssrg_warp_canvas(VERTEX,MODEL_MATRIX);}
void fragment(){
 vec4 art=texture(artwork,UV);
 ALBEDO=art.rgb*base_color.rgb;
 ALPHA=art.a*base_color.a;
}
