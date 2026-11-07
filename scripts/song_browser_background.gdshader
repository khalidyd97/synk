shader_type canvas_item;
// Signal Arcade backdrop: a violet glow rising from below, a perspective lane grid
// flowing toward the player, faint stars above the horizon and CRT scanlines.
uniform vec4 ambience : source_color = vec4(0.12,0.08,0.28,1.0);
uniform float clock=0.0;
uniform float horizon=0.62;
uniform float grid_strength=1.0;
uniform float overlay=0.0;   // 1: draw only the light (grid, glow, scanlines) over other art
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float grid_line(float v,float width){
    float d=abs(fract(v)-.5);
    float w=fwidth(v)*width;
    return 1.0-smoothstep(.5-w,.5,d+0.0001);
}
void fragment(){
    vec2 uv=UV;
    vec3 base=vec3(.027,.027,.059);
    vec3 light=vec3(0.0);
    // Violet bloom from below the floor and a cool haze at the horizon.
    vec2 g=uv-vec2(.5,1.18);
    light+=vec3(.08,.025,.16)*exp(-dot(g*vec2(1.0,1.6),g*vec2(1.0,1.6))*2.6);
    light+=ambience.rgb*.06*smoothstep(.2,1.0,uv.y);
    light+=vec3(.05,.22,.3)*exp(-pow((uv.y-horizon)*14.0,2.0))*.6;
    // Floor grid below the horizon: thirteen lanes converge, rows stream forward.
    if(uv.y>horizon){
        float depth=uv.y-horizon;
        float x=(uv.x-.5)/max(depth,.0008);
        float z=.32/max(depth,.0008);
        float fade=smoothstep(0.0,.12,depth);
        float lanes=grid_line(x*.9+.5,1.4);
        float rows=grid_line(z-clock*1.6,1.2);
        vec3 cyan=vec3(.25,.95,1.0);
        vec3 magenta=vec3(1.0,.24,.6);
        light+=cyan*lanes*.32*fade*grid_strength;
        light+=magenta*rows*.22*fade*grid_strength;
        // A pulse of light rushing toward the player every beat-ish.
        float pulse=exp(-pow(fract(z*.12-clock*.45)-.5,2.0)*60.0);
        light+=magenta*pulse*.05*fade*grid_strength;
    } else {
        vec2 stars=uv*vec2(180.0,100.0)+vec2(clock*.15,0.0);
        vec2 cell=floor(stars);
        float star=step(.995,hash(cell))*exp(-length(fract(stars)-.5)*7.0);
        light+=vec3(.55,.75,1.0)*star*(.35+.2*sin(clock*.9+hash(cell)*6.283))*smoothstep(0.0,horizon,uv.y);
    }
    // Horizon line.
    light+=mix(vec3(.25,.95,1.0),vec3(1.0,.24,.6),uv.x)*exp(-abs(uv.y-horizon)*900.0)*.55*grid_strength;
    // Scanlines and a soft vignette.
    float scan=.92+.08*sin(SCREEN_UV.y/SCREEN_PIXEL_SIZE.y*3.14159*.66);
    vec2 v=uv-.5;
    float vignette=1.0-dot(v,v)*.9;
    vec3 color=(base+light)*scan*vignette;
    if(overlay>.5){
        float a=clamp(max(max(light.r,light.g),light.b)*1.6,0.0,1.0);
        COLOR=vec4(light*scan/max(a,.001),a*.85)*COLOR;
    } else {
        COLOR=vec4(color,1.0)*COLOR;
    }
}
