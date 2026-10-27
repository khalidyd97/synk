// SSRG approach curve. Notes keep a linear track z (time to the line times travel speed),
// and this moves them to the depth where the perspective camera draws them at SSRG's
// progress p = (K^u - 1)/(K - 1), u = 1 + z/L: out of the vanishing point, growing with p.
// x: 1 when SSRG gameplay is on, y: K, z: camera depth constant Z (p = Z/(Z - z) on the
// track plane), w: linear track length L. Mirrored by ssrg_warped_z() in highway_3d.gd.
global uniform vec4 ssrg_warp;
float ssrg_warp_z(float z){
    if(ssrg_warp.x<0.5) return z;
    float k=ssrg_warp.y, depth=ssrg_warp.z, track=ssrg_warp.w;
    // Past the line, carry on at the speed notes arrive with.
    if(z>=0.0) return z*depth*k*log(k)/((k-1.0)*track);
    float u=max(1.0+z/track,0.0);
    float p=max((pow(k,u)-1.0)/(k-1.0),0.012);
    return depth*(1.0-1.0/p);
}
// SSRG hides its vanishing point behind the song card: notes first show at about p = 0.19,
// already small pucks, rather than growing visibly out of a speck. 1 elsewhere.
float ssrg_reveal(float z){
    if(ssrg_warp.x<0.5) return 1.0;
    float k=ssrg_warp.y;
    float p=(pow(k,clamp(1.0+z/ssrg_warp.w,0.0,1.0))-1.0)/(k-1.0);
    return smoothstep(0.16,0.21,p);
}
// Moves a whole mesh with its origin, so note art keeps its shape.
vec3 ssrg_warp_rigid(vec3 vertex, mat4 model){
    float centre=model[3].z;
    return vertex+inverse(mat3(model))*vec3(0.0,0.0,ssrg_warp_z(centre)-centre);
}
// Moves a trail cross-section by the warp at its centreline depth (local z), so trails
// stretch between their warped ends while both edges stay the same width apart. Warping
// each edge by its own depth would pull diagonal bars apart near the vanishing point.
vec3 ssrg_warp_section(vec3 vertex, float section_z, mat4 model){
    float centre=(model*vec4(vertex.x,vertex.y,section_z,1.0)).z;
    return vertex+inverse(mat3(model))*vec3(0.0,0.0,ssrg_warp_z(centre)-centre);
}
