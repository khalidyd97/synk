shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
uniform sampler2D artwork : source_color, filter_linear_mipmap, repeat_disable;
uniform bool along_rail = true;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec3 floor_tint : source_color = vec3(0.0);
uniform float floor_opacity = 1.0;
uniform float rail_entrance : hint_range(0.0,1.0) = 1.0;
uniform float floor_entrance : hint_range(0.0,1.0) = 1.0;
uniform float rail_side = 1.0;
// A second copy of the rail drawn above the judgment bar: the rail's light only, no road.
uniform bool rail_only = false;
// SYNK mode: a flare that loops round the highway, up one rail and down the other, with
// strands of light spiralling out behind it. Drawn on the light-only copy of the rail.
uniform bool rail_flare = false;
uniform float flare_phase = 0.0;
// +1: the flare travels toward the player (down the rail); -1: away, up the rail.
uniform float flare_direction = 1.0;
// The rail's centre line and half-width in this sprite, as u = x * v + y (measured from the
// rail art by tools/make_synk_mode_art.py's rail_edges).
uniform vec2 rail_centre = vec2(-0.784, 0.96095);
uniform vec2 rail_half_width = vec2(0.04416, 0.00354);
global uniform float synk_time;
void vertex(){
    // Each half arrives gently from its outer edge while its rail is being drawn.
    VERTEX.x+=rail_side*(1.0-rail_entrance)*.72;
}
void fragment(){
    vec2 uv=along_rail ? vec2(1.0-UV.y,UV.x) : UV;
    vec4 art=texture(artwork,uv);
    bool road=max(art.r,max(art.g,art.b))<0.05;
    // Draw the rail down its length instead of fading the complete silhouette at once.
    float rail_wipe=1.0-smoothstep(rail_entrance,rail_entrance+.075,UV.y);
    float leading_edge=exp(-pow((UV.y-rail_entrance)*24.0,2.0))
        *smoothstep(0.0,.08,rail_entrance)*(1.0-smoothstep(.88,1.0,rail_entrance));
    ALBEDO=road?floor_tint:art.rgb*tint.rgb*(1.0+leading_edge*1.65);
    EMISSION=road?vec3(0.0):art.rgb*tint.rgb*leading_edge*.85;
    ALPHA=art.a*tint.a*(road?floor_opacity*floor_entrance:rail_wipe*smoothstep(0.0,.16,rail_entrance));
    if(rail_only){
        // Only the light itself: the rail's dim outer glow must not darken the bar under it.
        float light=max(art.r,max(art.g,art.b));
        ALBEDO=art.rgb/max(light,0.001)*tint.rgb*(1.0+leading_edge*1.65);
        // Fade the faintest glow out smoothly, so it leaves no edge across the bar.
        ALPHA=art.a*tint.a*rail_wipe*smoothstep(0.0,.16,rail_entrance)*light*smoothstep(0.02,0.22,light);
        if(rail_flare){
            // The flare loops round the highway: up the left rail to the far end, then down
            // the right rail, again and again. Each rail's flare runs one way and wraps;
            // the right rail is half a lap behind the left, so one hands over to the other.
            float lap=fract(synk_time*0.26+flare_phase);
            float where=flare_direction>0.0?mix(-0.25,1.3,lap):mix(1.3,-0.25,lap);
            float along=(UV.y-where)*flare_direction;      // > 0 ahead of the head, < 0 behind it
            float half_width=rail_half_width.x*UV.y+rail_half_width.y;
            float across=(UV.x-(rail_centre.x*UV.y+rail_centre.y))/half_width;   // in rail widths
            float head=exp(-pow(along/0.04,2.0));
            // A long tail behind the head, a short falloff in front of it.
            float tail=along<0.0?exp(along/0.24):exp(-pow(along/0.045,2.0));
            // Three strands spiralling out of the head: tight at the head, opening behind it,
            // the far side of each turn dimmer so they read as winding round the rail.
            float open=0.35+2.9*smoothstep(0.0,-0.22,along);
            float strands=0.0;
            for(int strand=0;strand<3;strand++){
                float turn=along*30.0+synk_time*5.5*flare_direction+float(strand)*2.0944;
                float offset=sin(turn)*open;
                float depth=0.5+0.5*cos(turn);
                strands+=exp(-pow((across-offset)/0.27,2.0))*depth;
            }
            // The head: a hot bloom with a four-point sparkle across the rail.
            float bloom=exp(-pow(across/1.5,2.0))*head;
            float star=exp(-pow(along/0.011,2.0))*exp(-abs(across)/2.6)*exp(-pow(across/7.0,2.0))+exp(-pow(across/0.5,2.0))*exp(-abs(along)/0.07);
            // Glints left twinkling in the tail.
            vec2 cell=floor(vec2(UV.y*70.0,across*1.2+8.0));
            float pick=fract(sin(dot(cell,vec2(127.1,311.7)))*43758.5453);
            vec2 spot=vec2(fract(UV.y*70.0),fract(across*1.2+8.0))-0.5;
            float glint=step(0.82,pick)*smoothstep(0.32,0.0,length(spot))*(0.5+0.5*sin(synk_time*11.0+pick*40.0))*exp(-pow(across/3.2,2.0));
            // The rail itself runs hot where the flare is passing.
            float hot=exp(-pow(across/0.8,2.0))*tail;
            float ends=smoothstep(0.06,0.2,UV.y)*rail_wipe;
            float glow=(strands*1.15*tail+bloom*1.9+star*0.9+glint*tail*1.2+hot*0.7)*ends;
            vec3 flare_color=mix(tint.rgb*vec3(1.0,0.60,0.24),vec3(1.0,0.96,0.88),clamp(bloom*1.4+star+strands*0.3+glint,0.0,1.0));
            ALBEDO=mix(ALBEDO,flare_color,clamp(glow/max(ALPHA+glow,0.001),0.0,1.0));
            ALPHA=clamp(ALPHA+glow,0.0,1.0);
        }
    }
}
