// SSRG Playables: notes fall at a steady pace on screen instead of a steady pace along the 3D
// floor, so holds and slides keep their on-screen length all the way down. A point's distance
// along the track (z, 0 at the judgement line, -length at the far end) becomes a screen
// position spaced evenly from the line to the far end, then is put back on the floor at
// that position. z = 0 stays at the line, so timing and touch are unchanged.
// highway_3d.gd sets the globals each frame; only materials with screen_warp on are moved.
global uniform vec4 ssrg_camera;   // camera height, camera z, sin(tilt), cos(tilt)
global uniform vec4 ssrg_screen;   // view tangent at the line, at the far end, track length, on
uniform bool screen_warp = false;
float warp_z(float z){
    if(!screen_warp || ssrg_screen.w < 0.5) return z;
    float s = clamp(-z / ssrg_screen.z, -0.35, 1.0);
    float u = mix(ssrg_screen.x, ssrg_screen.y, s);
    float h = ssrg_camera.x; float sp = ssrg_camera.z; float cp = ssrg_camera.w;
    return ssrg_camera.y - h * (cp + u * sp) / (sp - u * cp);
}
