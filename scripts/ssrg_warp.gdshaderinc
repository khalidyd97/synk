// Original 2D chart projection. x enabled, y exponent, z source stage height,
// w linear timing track length. The orthographic camera adds no scaling.
global uniform vec4 ssrg_warp;
// Chart progress where notes appear. SKD gameplay uses 0.5 (its cover tile hides the far end);
// the recorder has no cover, so it starts notes where the rails begin.
global uniform float ssrg_reveal_from;
// Above 0 in the recorder's Correct mode: the far-end scale of an even view on the same
// stage. Time maps linearly to height and size from this scale up to 1 at the judgment
// line, so notes stay on the rails, evenly spaced, and never shrink to a point.
global uniform float ssrg_even;
// Bending road (prototype): the road swings sideways in an S and comes back. x is the swing
// in world units (0 = straight), y the seconds until the swing reaches the judgment line,
// z how long it lasts, w how many seconds of road the screen shows ahead of the line.
global uniform vec4 ssrg_bend;
// Sideways shift of the road at canvas height q (0 = far end, 1 = judgment line). Mirrored
// by bend_at() in highway_3d.gd.
float ssrg_bend_at(float q){
    if(ssrg_bend.x==0.0) return 0.0;
    float u=((1.0-min(q,1.0))*ssrg_bend.w-ssrg_bend.y)/ssrg_bend.z;
    if(u<=0.0||u>=1.0) return 0.0;
    return ssrg_bend.x*1.299*sin(6.2831853*u)*sin(3.1415927*u);
}
float ssrg_progress(float z){ return max(1.0+z/ssrg_warp.w,0.0); }
// Height on the canvas for a chart progress p.
float ssrg_depth_of(float p){ return ssrg_even>0.0?mix(ssrg_even,1.0,p):pow(p,ssrg_warp.y); }
float ssrg_reveal_z(){ return ssrg_warp.z*(ssrg_depth_of(ssrg_reveal_from)-1.0); }
// Width and size scale: the same q as the height (q=p^6 in SKD), so lanes stay straight.
float ssrg_scale(float z){ return ssrg_depth_of(ssrg_progress(z)); }
// A point at track position (x, z) across on the drawn canvas: narrowed by the perspective
// and moved with the bending road.
float ssrg_canvas_x(float x, float z){
    float q=ssrg_scale(z);
    return x*q+ssrg_bend_at(q);
}
float ssrg_warp_z(float z){
    if(ssrg_warp.x<0.5) return z;
    return ssrg_warp.z*(ssrg_depth_of(ssrg_progress(z))-1.0);
}
float ssrg_reveal(float z){
    if(ssrg_warp.x<0.5) return 1.0;
    return step(ssrg_reveal_from,ssrg_progress(z));
}
// Position and full sprite dimensions share q=p^6, as IngameRenderer does.
vec3 ssrg_warp_rigid(vec3 vertex, mat4 model){
    if(ssrg_warp.x<0.5) return vertex;
    vec3 centre=model[3].xyz;
    float q=ssrg_scale(centre.z);
    vec3 point=(model*vec4(vertex,1.0)).xyz;
    vec3 target=vec3(centre.x*q+ssrg_bend_at(q),centre.y,ssrg_warp_z(centre.z));
    return vertex+inverse(mat3(model))*(target-centre+(point-centre)*(q-1.0));
}
// A connector is straight between projected cross-sections, with the same
// position/width scale as the note at each endpoint.
vec3 ssrg_warp_section(vec3 vertex, float section_z, mat4 model){
    if(ssrg_warp.x<0.5) return vertex;
    vec3 point=(model*vec4(vertex,1.0)).xyz;
    float centre=(model*vec4(vertex.x,vertex.y,section_z,1.0)).z;
    float q=ssrg_scale(centre);
    vec3 target=vec3(point.x*q+ssrg_bend_at(q),point.y,ssrg_warp_z(centre)+(point.z-centre)*q);
    return vertex+inverse(mat3(model))*(target-point);
}

// Static SYNK road/rail geometry uses the same canvas and cross-section taper.
vec3 ssrg_warp_canvas(vec3 vertex, mat4 model){
    if(ssrg_warp.x<0.5) return vertex;
    vec3 point=(model*vec4(vertex,1.0)).xyz;
    float q=ssrg_scale(point.z);
    vec3 target=vec3(point.x*q+ssrg_bend_at(q),point.y,ssrg_warp_z(point.z));
    return inverse(mat3(model))*(target-model[3].xyz);
}
