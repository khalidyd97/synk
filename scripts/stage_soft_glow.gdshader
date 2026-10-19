shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform vec3 tint : source_color=vec3(.1,.8,1.0);
uniform float clock=0.0;
uniform float strength=1.0;
uniform float rail_x=10.0;
uniform float width=6.0;
uniform float phase_offset=0.0;
varying vec3 stage_position;
void vertex(){stage_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
    float outside=(abs(stage_position.x)-rail_x)/width;
    float feather=smoothstep(0.0,.035,outside)*(1.0-smoothstep(.65,1.0,outside));
    float haze=pow(max(0.0,1.0-outside),2.0);
    float drift=.76+.12*sin(stage_position.z*.25+outside*7.0-clock*.32+phase_offset);
    drift+=.07*sin(stage_position.z*.43-outside*11.0+clock*.21);
    float near_glow=mix(.4,1.0,smoothstep(-45.0,0.0,stage_position.z));
    float fade=smoothstep(-60.0,-38.0,stage_position.z)*(1.0-smoothstep(.5,2.0,stage_position.z));
    ALBEDO=tint*1.3;
    ALPHA=haze*feather*drift*near_glow*fade*.65*strength;
}
