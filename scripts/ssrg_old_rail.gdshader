shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
uniform bool inner_at_high_uv=false;
uniform float entrance : hint_range(0.0,1.0) = 1.0;
void fragment(){
    float u=inner_at_high_uv?UV.y:1.0-UV.y;
    float outside=smoothstep(.015,.05,u)*(1.0-smoothstep(.96,.995,u));
    float outer_white=smoothstep(.03,.09,u)*(1.0-smoothstep(.22,.28,u));
    float inner_white=smoothstep(.37,.46,u)*(1.0-smoothstep(.68,.78,u));
    float inner_silver=smoothstep(.81,.86,u)*(1.0-smoothstep(.94,.98,u));
    vec3 steel=vec3(.77,.80,.84);
    steel=mix(steel,vec3(.98,.99,1.0),outer_white);
    steel=mix(steel,vec3(.97,.98,1.0),inner_white);
    steel=mix(steel,vec3(.88,.91,.95),inner_silver);
    float wipe=smoothstep(UV.x-.08,UV.x,entrance);
    float edge=exp(-pow((UV.x-entrance)*20.0,2.0))*(1.0-smoothstep(.88,1.0,entrance));
    ALBEDO=steel*(1.0+edge*1.2);
    EMISSION=steel*edge*.55;
    ALPHA=outside*wipe*smoothstep(0.0,.14,entrance);
}
