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
// SYNK mode: a flare that travels up and down the rail, with two strands of light
// spiralling around it. Drawn on the light-only copy of the rail (rail_only).
uniform bool rail_flare = false;
uniform float flare_phase = 0.0;
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
            // Where the flare is along the rail: it glides up and back down, easing at the ends.
            float where=0.5+0.42*sin(synk_time*0.85+flare_phase);
            float along=UV.y-where;
            float near_flare=exp(-pow(along/0.15,2.0));
            float half_width=rail_half_width.x*UV.y+rail_half_width.y;
            float across=(UV.x-(rail_centre.x*UV.y+rail_centre.y))/half_width;   // in rail widths
            // Two strands winding round the rail, half a turn apart; the far side of each
            // turn is dimmer, so they read as wrapping around it.
            float flare=0.0;
            for(int strand=0;strand<2;strand++){
                float turn=along*24.0-synk_time*4.0+float(strand)*3.14159;
                float offset=sin(turn)*2.7*near_flare;
                float depth=0.55+0.45*cos(turn);
                flare+=exp(-pow((across-offset)/0.30,2.0))*depth;
            }
            // The bloom at the flare's heart, stretched along the rail.
            float bloom=exp(-pow(across/1.3,2.0))*exp(-pow(along/0.07,2.0));
            float glow=(flare*1.25+bloom*1.5)*near_flare*rail_wipe*smoothstep(0.1,0.3,UV.y);
            vec3 flare_color=mix(tint.rgb*vec3(1.0,0.62,0.26),vec3(1.0,0.95,0.86),clamp(bloom+flare*0.35,0.0,1.0));
            ALBEDO=mix(ALBEDO,flare_color,clamp(glow/max(ALPHA+glow,0.001),0.0,1.0));
            ALPHA=clamp(ALPHA+glow,0.0,1.0);
        }
    }
}
