shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(1.0,.86,.25,1.0);
uniform float progress : hint_range(0.0,1.0) = 0.0;
uniform float strength : hint_range(0.0,2.0) = 0.0;
uniform float near_z = 0.15;
uniform float far_z = -9.35;
varying float world_z;

void vertex(){
    world_z=(MODEL_MATRIX*vec4(VERTEX,1.0)).z;
}

void fragment(){
    float head=mix(near_z,far_z,progress);
    float distance_to_head=abs(world_z-head);
    float core=exp(-pow(distance_to_head/.055,2.0));
    float halo=exp(-pow(distance_to_head/.24,2.0));
    // The trail remains on the judgment side of the travelling head.
    float behind=smoothstep(head-.02,head+.04,world_z);
    float trail=behind*exp(-max(world_z-head,0.0)*1.45);
    float side=smoothstep(0.0,.035,UV.x)*smoothstep(0.0,.035,1.0-UV.x);
    ALBEDO=color.rgb*(1.0+core*1.8);
    EMISSION=color.rgb*(core*2.6+halo*1.1+trail*.32)*strength;
    ALPHA=(core+halo*.52+trail*.16)*side*strength;
}
