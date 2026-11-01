shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;
uniform vec3 tint : source_color=vec3(0.2,0.8,1.0);
uniform float frame=0.0;
uniform float opacity=1.0;
uniform float particles=1.0;
uniform float style=0.0;
uniform float direction=0.0;
uniform float seed=0.0;
float hash(float n){return fract(sin(n*91.73+seed*17.13)*43758.54);}
void fragment(){
    // Eleven distinct frames, stepped by the shared 33 fps source clock.
    float t=clamp(floor(frame),0.0,10.0)/10.0;
    vec2 p=(UV-.5)*2.0;
    if(length(p)>1.0 || opacity<=0.0)discard;
    float fade=pow(1.0-t,1.25);
    float d=length(p*vec2(1.0,1.65));
    float radius=.28+.55*sqrt(t);
    float shock=exp(-pow((d-radius)/.026,2.0));
    float echo=exp(-pow((d-radius*.72)/.018,2.0))*(.25+style*.6);
    float core=exp(-dot(p*vec2(7.0,18.0),p*vec2(7.0,18.0)));
    float spike=exp(-abs(p.x)*85.0)*(1.0-smoothstep(.1,.8,abs(p.y)))*pow(1.0-t,1.6);
    float sweep=exp(-abs(p.y)*65.0-abs(p.x)*5.0)*pow(1.0-t,1.6);
    float halo=exp(-d*d*5.5)*(.70+style*.45);
    vec2 lift=(p-vec2(0.0,-.12-.25*t))*vec2(4.0,3.0);
    float rising_glow=exp(-dot(lift,lift))*.6*(1.0-t);
    float angle=atan(p.y*1.3,p.x);
    float rays=pow(max(cos(angle*6.0+t*.5),0.0),16.0)*exp(-d*3.0);
    rays*=1.0-smoothstep(.1+.5*t,.3+.65*t,d);
    rays*=pow(1.0-t,1.4)*particles;
    float sparks=0.0;
    float spark_glow=0.0;
    float spark_white=0.0;
    for(int i=0;i<24;i++){
        if(float(i)>=floor(clamp(particles,0.0,1.0)*24.0))continue;
        float fi=float(i);
        float a=fi*2.399963+direction*1.5707963;
        vec2 axis=vec2(cos(a),sin(a)*.7);
        vec2 pos=axis*(.10+(.35+hash(fi)*.35)*t);
        if(i%2==1){
            axis=vec2((hash(fi+10.0)-.5)*1.1,-.6-hash(fi+40.0)*.8);
            pos=vec2((hash(fi+50.0)-.5)*.16,.02)+axis*t+vec2(0.0,.55*t*t);
        }
        vec2 off=p-pos;
        float along=dot(off,normalize(axis));
        float across=dot(off,normalize(vec2(-axis.y,axis.x)));
        float head=exp(-dot(off,off)/.00020);
        float streak=exp(-pow(across/.009,2.0)-pow(along/(.025+.07*t),2.0));
        sparks+=head+streak;
        spark_glow+=exp(-dot(off,off)/.0015)*.45;
        spark_white+=head*.9+streak*.55;
    }
    vec3 color=tint*(halo+rising_glow+shock*1.8+echo+sparks*2.4+spark_glow+rays*2.4);
    color+=vec3(1.0)*(core*3.2+spike*2.0+sweep+shock*.55+rays*.6+spark_white);
    float edge=1.0-smoothstep(.82,1.0,length(p));
    ALBEDO=color;
    ALPHA=clamp(halo+rising_glow+core+spike+sweep+shock+echo+sparks+spark_glow+rays*.7,0.0,1.0)*fade*edge*opacity;
}
