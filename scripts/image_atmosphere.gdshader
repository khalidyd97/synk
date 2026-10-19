shader_type canvas_item;
uniform float clock=0.0;
uniform bool overlay_only=false;
uniform float artwork_palette=0.0;
uniform vec4 palette_primary : source_color=vec4(1.0);
uniform vec4 palette_secondary : source_color=vec4(1.0);
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void fragment(){
    vec2 uv=UV;
    vec2 drift=vec2(sin(clock*.12),cos(clock*.095))*.003;
    vec4 base=texture(TEXTURE,clamp((uv-.5)*.99+.5+drift,vec2(0.0),vec2(1.0)))*COLOR;
    vec2 grid=uv*vec2(100.0,60.0)+vec2(clock*.65,-clock*.24);
    float mote=step(.994,hash(floor(grid)))*exp(-length(fract(grid)-.5)*8.0);
    float sweep=exp(-pow((uv.x-uv.y*.6-fract(clock*.025)*2.0+.5)*14.0,2.0));
    vec3 glow=mix(vec3(.04,.6,.85),vec3(.65,.08,.65),uv.x);
    glow=mix(glow,mix(palette_primary.rgb,palette_secondary.rgb,uv.x),artwork_palette);
    if(overlay_only){COLOR=vec4(glow,mote*.26+sweep*.035)*COLOR;}
    else{COLOR=vec4(base.rgb+glow*(mote*.22+sweep*.035),base.a);}
}
