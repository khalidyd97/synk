shader_type canvas_item;
uniform vec4 ambience : source_color = vec4(0.12,0.08,0.28,1.0);
uniform float clock=0.0;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void fragment(){
    vec2 uv=UV;
    vec3 color=vec3(.018,.016,.045);
    color+=ambience.rgb*.055*(1.0-uv.y);
    vec2 haze=uv-vec2(.3+sin(clock*.11)*.14,.65+cos(clock*.09)*.12);
    color+=vec3(.015,.06,.09)*exp(-dot(haze,haze)*7.0);
    for(int i=0;i<5;i++){
        float n=float(i);
        float y=.24+uv.x*.43+n*.026+sin(uv.x*9.0+n*.6+clock*.2)*.018;
        float line=exp(-abs(uv.y-y)*190.0);
        color+=mix(vec3(.02,.38,.48),vec3(.3,.02,.34),uv.x)*line*.11;
        float packet=exp(-pow((fract(uv.x-clock*.055+n*.17)-.5)*13.0,2.0));
        color+=mix(vec3(.05,.6,.8),vec3(.6,.08,.55),uv.x)*line*packet*.20;
    }
    vec2 stars=uv*vec2(190.0,110.0)+vec2(clock*.23,clock*.10);
    vec2 cell=floor(stars);
    float star=step(.996,hash(cell))*exp(-length(fract(stars)-.5)*7.0);
    color+=vec3(.25,.45,.65)*star*(.42+.18*sin(clock*.7+hash(cell)*6.283));
    vec2 near_stars=uv*vec2(95.0,55.0)+vec2(clock*.41,-clock*.14);
    float mote=step(.998,hash(floor(near_stars)+37.0))*exp(-length(fract(near_stars)-.5)*8.0);
    color+=vec3(.15,.5,.7)*mote*.32;
    COLOR=vec4(color,1.0)*COLOR;
}
