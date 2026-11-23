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
    // Grow a soft shaft from the judgment bar toward the moving tip. The plane
    // lies on the road, so perspective keeps it aligned with the highway angle.
    float reached=smoothstep(head-.10,head+.10,world_z);
    float tip=exp(-pow(distance_to_head/.34,2.0));
    float tip_bloom=exp(-pow(distance_to_head/.82,2.0));
    // This recovered stage uses a direct 2D canvas, so taper explicitly: wide at
    // the judgment bar and progressively narrower toward the vanishing point.
    float depth=clamp((near_z-world_z)/(near_z-far_z),0.0,1.0);
    float half_width=mix(.50,.025,pow(depth,.72));
    float across=abs(UV.x-.5);
    float centre=1.0-smoothstep(half_width*.24,half_width*.62,across);
    float feather=1.0-smoothstep(half_width*.40,half_width,across);
    float root=mix(.58,1.0,smoothstep(0.0,.12,depth));
    float shaft=reached*root*(centre*.34+feather*.12);
    float light=(shaft+tip*centre*.62+tip_bloom*feather*.18)*strength;
    ALBEDO=color.rgb*(.68+tip_bloom*.38);
    EMISSION=color.rgb*light*1.8;
    ALPHA=light*.46;
}
