// SYNK mode note shapes (Settings > Visuals > Notes). The round note art is bent into
// another outline as it is drawn: every contour of the chosen shape takes the art of the
// circle of the same size, so the rims, glass face and highlights stay as painted.
// 0 round, 1 soft rectangle, 2 sharp rectangle, 3 slim bar, 4 cut corners, 5 pill,
// 6 tile on the road, 7 pointed ends.
uniform int note_shape = 0;
// Where the round note sits in its sprite: centre and radii, in UV.
uniform vec4 shape_box = vec4(0.5, 0.5, 0.5, 0.5);
// 1 for flicks: the chevrons above the note keep their own shape.
uniform float shape_keep_above = 0.0;
const float SYNK_SHAPE_ASPECT = 2.08;   // the note is about twice as wide as it is tall

// Size of the shape's contour through p (1 on the note's outline).
float synk_shape_size(vec2 p){
    vec2 a=abs(p);
    if(note_shape==1) return pow(pow(a.x,4.0)+pow(a.y,4.0),0.25);
    if(note_shape==2) return pow(pow(a.x,10.0)+pow(a.y,10.0),0.1);
    if(note_shape==3){ a.y/=0.58; return pow(pow(a.x,10.0)+pow(a.y,10.0),0.1); }
    if(note_shape==4) return max(max(a.x,a.y),(a.x+a.y)/1.62);
    if(note_shape==5) return length(vec2(max(a.x*SYNK_SHAPE_ASPECT-(SYNK_SHAPE_ASPECT-1.0),0.0),a.y));
    if(note_shape==6){ a.x/=max(0.2,1.0+0.13*p.y); return pow(pow(a.x,10.0)+pow(a.y,10.0),0.1); }
    if(note_shape==7) return max(a.y,a.x+a.y*0.42);
    return length(p);
}
vec2 synk_shape_uv(vec2 uv){
    if(note_shape==0) return uv;
    vec2 p=(uv-shape_box.xy)/shape_box.zw;
    float across=max(length(p),0.00001);
    vec2 bent=shape_box.xy+p*(synk_shape_size(p)/across)*shape_box.zw;
    return mix(bent,uv,shape_keep_above*smoothstep(-1.0,-1.5,p.y));
}
