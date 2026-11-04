shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
// Flat painted stage bitmap, using the same canvas transform as the live notes.
uniform sampler2D artwork:source_color,filter_linear_mipmap,repeat_disable;
uniform float rail_fraction=.0379147;
uniform float source_rail_fraction=.085;
uniform float inner_edge_fraction=.025;
uniform float source_edge_end=.17;
uniform bool recolor_rails=false;
uniform vec3 tint:source_color=vec3(1.0);
uniform float image_half_width=10.55;
#include "res://scripts/ssrg_warp.gdshaderinc"
varying vec2 canvas_position;
void vertex(){
 VERTEX=ssrg_warp_canvas(VERTEX,MODEL_MATRIX);
 canvas_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz;
}
void fragment(){
 // Recover the original bitmap coordinates from the flat SSRG canvas. Ordinary
 // triangle UV interpolation would shear the picture where the far edge collapses.
 float q=max(.00001,1.0+canvas_position.y/ssrg_warp.z);
 float raw_z=(pow(q,1.0/ssrg_warp.y)-1.0)*ssrg_warp.w;
 vec2 sprite_uv=vec2(canvas_position.x/(2.0*image_half_width*q)+.5,(raw_z+60.0)/64.0);
 // Fit the painted frames outside the exact playable boundary, independently
 // of the artist's border width. The center image never replaces note positions.
 float x=clamp(sprite_uv.x,0.0,1.0);
 float u=x;
 bool rail=x<rail_fraction || x>1.0-rail_fraction;
 bool edge_detail=x<rail_fraction+inner_edge_fraction || x>1.0-rail_fraction-inner_edge_fraction;
 if(x<rail_fraction){u=x/rail_fraction*source_rail_fraction;}
 else if(x>1.0-rail_fraction){u=1.0-(1.0-x)/rail_fraction*source_rail_fraction;}
 else if(x<rail_fraction+inner_edge_fraction){u=mix(source_rail_fraction,source_edge_end,(x-rail_fraction)/inner_edge_fraction);}
 else if(x>1.0-rail_fraction-inner_edge_fraction){u=1.0-mix(source_rail_fraction,source_edge_end,(1.0-x-rail_fraction)/inner_edge_fraction);}
 vec4 art=texture(artwork,vec2(u,sprite_uv.y));
 if(rail && recolor_rails){float light=dot(art.rgb,vec3(.3,.59,.11));art.rgb=mix(tint*light,vec3(light),smoothstep(.65,1.0,light)*.6);}
 // Keep only the outer frames and their narrow inside-edge details; center stays black.
 ALBEDO=edge_detail?art.rgb:vec3(0.0);
 ALPHA=edge_detail?art.a*smoothstep(-60.0,-51.0,raw_z):1.0;
}
