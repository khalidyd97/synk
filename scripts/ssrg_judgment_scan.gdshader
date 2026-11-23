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
    // A wide, feathered wash with no opaque core: the highway catches a moving
    // bloom rather than having a solid horizontal stripe drawn over it.
    float glow=exp(-pow(distance_to_head/.30,2.0));
    float bloom=exp(-pow(distance_to_head/.72,2.0));
    float behind=smoothstep(head-.08,head+.12,world_z);
    float afterglow=behind*exp(-max(world_z-head,0.0)*1.15);
    float side=pow(smoothstep(0.0,.18,UV.x)*smoothstep(0.0,.18,1.0-UV.x),.65);
    float light=(glow*.52+bloom*.24+afterglow*.10)*side*strength;
    ALBEDO=color.rgb*(.72+bloom*.42);
    EMISSION=color.rgb*light*1.65;
    ALPHA=light*.48;
}
