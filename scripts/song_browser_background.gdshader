shader_type canvas_item;
// Album Takeover backdrop: the current song's cover colours as slow, soft light pooling on
// near-black, with a little film grain. No grid, no scanlines.
uniform vec4 color_a : source_color = vec4(0.85,0.55,0.35,1.0);
uniform vec4 color_b : source_color = vec4(0.25,0.55,0.50,1.0);
uniform float clock=0.0;
uniform float overlay=0.0;   // 1: only grain and vignette, over other art
uniform float strength=1.0;
// Kept so older callers that still set them do not fail.
uniform vec4 ambience : source_color = vec4(0.0);
uniform float horizon=0.62;
uniform float grid_strength=1.0;

float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float pool(vec2 uv, vec2 c, vec2 r){vec2 d=(uv-c)/r; return exp(-dot(d,d));}

void fragment(){
    vec2 uv=UV;
    float t=clock;
    vec3 base=vec3(.045,.047,.052);
    vec3 a=color_a.rgb, b=color_b.rgb;
    vec3 light=vec3(0.0);
    light+=a*.62*pool(uv,vec2(.22+.06*sin(t*.07),.38+.05*cos(t*.05)),vec2(.55,.75));
    light+=b*.50*pool(uv,vec2(.86+.05*cos(t*.06),.92+.04*sin(t*.08)),vec2(.5,.55));
    light+=mix(a,b,.5)*.22*pool(uv,vec2(.62+.08*sin(t*.04),.08),vec2(.35,.3));
    light*=strength;
    // Bright covers (orange, yellow, pastel) must not lift the page so far that light text
    // on it loses contrast: keep the hue, cap how bright the colour pools can get.
    float lum=dot(light,vec3(.299,.587,.114));
    light*=min(1.0,.24/max(lum,.0001));
    vec2 v=uv-.5;
    float vignette=1.0-dot(v*vec2(1.0,1.3),v*vec2(1.0,1.3))*.9;
    float grain=(hash(floor(FRAGCOORD.xy)+fract(t*7.0)*91.0)-.5)*.035;
    if(overlay>.5){
        float shade=clamp(1.0-vignette,0.0,1.0)*.8;
        COLOR=vec4(0.0,0.0,0.0,shade);
    } else {
        COLOR=vec4((base+light)*vignette+grain,1.0)*COLOR;
    }
}
