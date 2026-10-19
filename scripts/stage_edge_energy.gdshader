shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform vec3 tint : source_color=vec3(.1,.8,1.0);
uniform float clock=0.0;
uniform float strength=1.0;
uniform float phase_offset=0.0;
varying float stage_z;
void vertex(){stage_z=(MODEL_MATRIX*vec4(VERTEX,1.0)).z;}
void fragment(){
    // Packets travel from the distant end (negative z) toward the judgment line.
    float phase=mod(clock*12.0-stage_z+phase_offset,16.0);
    float tip=exp(-pow(min(phase,16.0-phase)/.85,2.0));
    float tail=exp(-phase/3.2)*(1.0-smoothstep(8.0,11.0,phase));
    float across=abs(UV.x-.5);
    float core=exp(-pow(across/.22,2.0));
    float wake=exp(-pow(across/.34,2.0));
    float fade=smoothstep(-60.0,-40.0,stage_z)*(1.0-smoothstep(.1,1.1,stage_z));
    ALBEDO=mix(tint,tint*.3+vec3(.9),tip*core*.85);
    ALPHA=(core*(tip*.95+tail*.85)+wake*tail*.25)*fade*strength;
}
