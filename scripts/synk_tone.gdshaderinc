// SYNK mode's adaptive colours. Its art is painted in gold; a tone turns that gold to the
// colour a song's cover gives the piece: (hue turn, saturation scale, value scale).
// The default leaves the art as painted.
vec3 synk_turn(vec3 rgb, vec3 turn){
    if(turn.x==0.0 && turn.y==1.0 && turn.z==1.0) return rgb;
    vec4 k=vec4(0.0,-1.0/3.0,2.0/3.0,-1.0);
    vec4 p=mix(vec4(rgb.bg,k.wz),vec4(rgb.gb,k.xy),step(rgb.b,rgb.g));
    vec4 q=mix(vec4(p.xyw,rgb.r),vec4(rgb.r,p.yzx),step(p.x,rgb.r));
    float d=q.x-min(q.w,q.y);
    vec3 hsv=vec3(abs(q.z+(q.w-q.y)/(6.0*d+0.0000001)),d/(q.x+0.0000001),q.x);
    hsv.x=fract(hsv.x+turn.x); hsv.y=clamp(hsv.y*turn.y,0.0,1.0); hsv.z*=turn.z;
    vec3 c=abs(fract(hsv.xxx+vec3(0.0,2.0/3.0,1.0/3.0))*6.0-3.0);
    return hsv.z*mix(vec3(1.0),clamp(c-1.0,0.0,1.0),hsv.y);
}
