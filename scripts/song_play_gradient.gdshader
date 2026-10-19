shader_type canvas_item;
uniform vec2 plate_size=vec2(400.0,64.0);
uniform vec3 start_color=vec3(.07,.73,.82);
uniform vec3 middle_color=vec3(.51,.26,1.0);
uniform vec3 end_color=vec3(.86,.14,.73);
varying vec2 local_position;
void vertex(){local_position=VERTEX;}
void fragment(){
    vec4 base=COLOR;
    // Tint the violet plate only; preserve white caption and border highlights.
    float plate=step(base.r,base.b)*step(base.g,base.r*.75);
    float x=local_position.x/max(plate_size.x,1.0);
    vec3 gradient=mix(start_color,middle_color,smoothstep(0.0,.6,x));
    gradient=mix(gradient,end_color,smoothstep(.45,1.0,x));
    COLOR=vec4(mix(base.rgb,gradient,plate),base.a);
}
