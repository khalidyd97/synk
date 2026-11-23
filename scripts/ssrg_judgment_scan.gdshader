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
    // Fill the complete usable road between the rails. Previously the visible
    // energy lived mainly in a narrow centre core, even though the scan mesh
    // itself covered the highway. Keep only a soft falloff at the rail edges.
    float full_width=1.0-smoothstep(half_width*.82,half_width,across);
    float inner_glow=1.0-smoothstep(half_width*.48,half_width*.96,across);
    float rail_bloom=exp(-pow((across-half_width*.88)/max(half_width*.16,.001),2.0));
    float root=mix(.58,1.0,smoothstep(0.0,.12,depth));
    float shaft=reached*root*(full_width*.32+inner_glow*.15+rail_bloom*.08);
    float light=(shaft+tip*full_width*.66+tip_bloom*(inner_glow*.25+rail_bloom*.12))*strength;
    ALBEDO=color.rgb*(.68+tip_bloom*.38);
    EMISSION=color.rgb*light*1.8;
    ALPHA=light*.46;
}
