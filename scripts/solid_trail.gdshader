shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
#include "res://scripts/highway_clip.gdshaderinc"
uniform vec3 tint : source_color=vec3(1.0,.73,.16);
uniform float clip_z=1000.0;
uniform float ghost_fade=1.0;
uniform float desaturate=0.0;
uniform bool joint=false;
uniform bool source_art=false;
uniform bool old_ssrg_art=false;
uniform bool joined_source=false;
uniform bool enhanced_synk=false;
// Recorder slides: SSRG-style gold ribbon with a cream core and a gentle flowing shimmer.
uniform bool ssrg_ribbon=false;
uniform float ssrg_half_width=0.0;
uniform float ssrg_line_x_scale=1.3;
uniform vec4 source_tint : source_color=vec4(1.0);
// SYNK mode: holds and slides are a wide beam of light drawn from the supplied beam art's
// cross-section (assets/synk_mode/trail_profile.png), with a few glints along it.
uniform bool synk_beam=false;
uniform sampler2D beam_profile : source_color, filter_linear, repeat_disable;
varying vec3 source_chip;
varying float source_layer;
varying float world_z;
#include "res://scripts/ssrg_warp.gdshaderinc"
void vertex(){
    source_chip=CUSTOM1.yzw;
    source_layer=CUSTOM1.x;
    // world_z stays the linear track position, so clip_z and the far fade are unchanged.
    world_z=(MODEL_MATRIX*vec4(VERTEX,1.0)).z;
    // Ribbons carry their centreline depth in UV2 (make_ribbon in highway_3d.gd).
    if(!joint && joined_source && ssrg_warp.x>0.5){
        // The two adjacent segments use this anchor's same projected miter.
        // Width is perpendicular to the projected path, including at bends.
        float section=MODEL_MATRIX[3].z+UV2.x;
        bool at_start=abs(UV2.x-CUSTOM0.y)<0.00001;
        float center_x=at_start?CUSTOM0.x:CUSTOM0.z;
        vec2 center=vec2(center_x*ssrg_scale(section),ssrg_warp_z(section));
        vec2 previous=vec2(CUSTOM2.x*ssrg_scale(MODEL_MATRIX[3].z+CUSTOM2.y),ssrg_warp_z(MODEL_MATRIX[3].z+CUSTOM2.y));
        vec2 following=vec2(CUSTOM2.z*ssrg_scale(MODEL_MATRIX[3].z+CUSTOM2.w),ssrg_warp_z(MODEL_MATRIX[3].z+CUSTOM2.w));
        vec2 incoming=center-previous;
        vec2 outgoing=following-center;
        if(length(incoming)<0.00001) incoming=outgoing;
        if(length(outgoing)<0.00001) outgoing=incoming;
        vec2 first=length(incoming)>0.00001?normalize(vec2(-incoming.y,incoming.x)):vec2(1.0,0.0);
        vec2 second=length(outgoing)>0.00001?normalize(vec2(-outgoing.y,outgoing.x)):first;
        vec2 sum=first+second;
        vec2 miter=length(sum)>0.00001?normalize(sum):second;
        float width=ssrg_half_width*ssrg_scale(section)+CUSTOM1.x;
        vec2 point=center+miter*(width*min(4.0,1.0/max(0.1,dot(miter,second))))*UV2.y;
        vec3 target=vec3(point.x,(MODEL_MATRIX*vec4(VERTEX,1.0)).y,point.y);
        VERTEX=inverse(mat3(MODEL_MATRIX))*(target-MODEL_MATRIX[3].xyz);
    }else if(!joint && ssrg_warp.x>0.5 && length(CUSTOM0)>0.0){
        // Original RenderLongLine measures its normal AFTER projecting endpoints.
        vec2 a=vec2(CUSTOM0.x*ssrg_scale(MODEL_MATRIX[3].z+CUSTOM0.y),ssrg_warp_z(MODEL_MATRIX[3].z+CUSTOM0.y));
        vec2 b=vec2(CUSTOM0.z*ssrg_scale(MODEL_MATRIX[3].z+CUSTOM0.w),ssrg_warp_z(MODEL_MATRIX[3].z+CUSTOM0.w));
        vec2 delta=b-a;
        vec2 normal=length(delta)>0.00001?normalize(vec2(-delta.y,delta.x)):vec2(1.0,0.0);
        float section=MODEL_MATRIX[3].z+UV2.x;
        bool at_start=abs(UV2.x-CUSTOM0.y)<0.00001;
        float perspective_width=enhanced_synk?mix(.72,1.0,clamp(ssrg_scale(section),0.0,1.0)):1.0;
        vec2 point=(at_start?a:b)+normal*vec2(ssrg_line_x_scale,1.0)*UV2.y*ssrg_half_width*ssrg_scale(section)*perspective_width;
        point.x+=UV2.y*CUSTOM1.x;
        vec3 target=vec3(point.x,(MODEL_MATRIX*vec4(VERTEX,1.0)).y,point.y);
        VERTEX=inverse(mat3(MODEL_MATRIX))*(target-MODEL_MATRIX[3].xyz);
    }else{
        VERTEX=joint?ssrg_warp_rigid(VERTEX,MODEL_MATRIX):ssrg_warp_section(VERTEX,UV2.x,MODEL_MATRIX);
    }
    rail_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}
// Player setting: how bright notes and their trails are (Settings > Visuals > Notes).
global uniform float synk_note_brightness;
uniform bool note_brightness_applies = true;
void fragment(){
    if(outside_rails(INV_VIEW_MATRIX[3].xyz)) discard;
    if(ssrg_warp.x>0.5){
        // Clip on the drawn judgment plane, not interpolated obsolete timing Z.
        if(rail_position.z>ssrg_warp_z(clip_z)) discard;
        if(rail_position.z<ssrg_reveal_z()) discard;
    }else if(world_z>clip_z) discard;
    vec3 color=source_art?source_chip:tint*.87;
    float opacity=source_art?.2:.8;
    if(ssrg_ribbon && !joint){
        float across=abs(UV.x*2.0-1.0);
        float core=pow(max(0.0,1.0-across),2.2);
        // Calm and steady: a matte band in the hold's soft gold with a slightly lighter core,
        // no moving shimmer, so long notes don't pull the eye while recording.
        color=mix(vec3(.902,.769,.486),vec3(.957,.945,.918),core*.25);
        opacity=.5+core*.15;
    }
    if(old_ssrg_art && source_art && !joint){
        color=mix(tint,vec3(1.0,.86,.78),.12);
        opacity=.58;
    }
    if(enhanced_synk && source_art && !joint){
        float core=pow(max(0.0,1.0-abs(UV.x*2.0-1.0)),2.4);
        if(source_layer>0.05){
            color=tint*1.25;
            opacity=.16*pow(max(0.0,1.0-abs(UV.x*2.0-1.0)),1.6);
        }else{
            color=mix(color,vec3(1.0,.98,.78),core*.72);
            opacity+=core*.10;
        }
    }
    if(synk_beam && source_art && !joint){
        // One face only: the source's three stacked layers would triple the beam.
        if(source_layer>0.0001) discard;
        vec4 beam=texture(beam_profile,vec2(UV.x,0.5));
        color=beam.rgb;
        opacity=beam.a*.9;
        // Glints: a few bright specks fixed along the beam, as in the art.
        vec2 cell=floor(vec2(UV.x*7.0,world_z*1.1));
        float pick=fract(sin(dot(cell,vec2(127.1,311.7)))*43758.5453);
        vec2 spot=vec2(fract(UV.x*7.0),fract(world_z*1.1))-.5;
        float glint=step(.93,pick)*smoothstep(.16,0.0,length(spot));
        color=mix(color,vec3(1.0),glint);
        opacity=max(opacity,glint*.9);
        // The far end is a plain square cut: the same diamond that marks a slide's bends sits
        // on it as the trail's last node (make_ribbon in highway_3d.gd).
        // It melts into the judgment line where it is being played, rather than a hard cut.
        if(ssrg_warp.x>0.5) opacity*=smoothstep(0.0,max(source_chip.y*1.4,0.0001),ssrg_warp_z(clip_z)-rail_position.z);
    }
    // SKD's l1/l2/l3 chips are fully opaque, uniform 6x6 texels. Their source
    // alpha is supplied by the batch color (.2 per overlapping quad), without
    // an invented soft edge or cream centre. Non-source ribbons keep the
    // shader feather used by SYNK's own trail styles.
    if(!joint && !source_art){
        float edge=min(UV.x,1.0-UV.x);
        float feather=max(fwidth(UV.x),.001);
        opacity*=smoothstep(0.0,feather,edge);
    }
    if(joint){
        float radius=length(UV-.5)*2.0;
        if(radius>1.0) discard;
        float center=1.0-smoothstep(.14,.64,radius);
        float rim=exp(-pow((radius-.80)*22.0,2.0));
        color=mix(tint,vec3(.98),center*.9)+tint*rim*.15;
        opacity=1.0-smoothstep(.94,1.0,radius);
    }
    float gray=dot(color,vec3(.299,.587,.114));
    ALBEDO=mix(color,vec3(gray*.6),desaturate)*source_tint.rgb;
    float missed_alpha=source_tint.a;
    ALPHA=(ssrg_warp.x>0.5 && source_tint.a<1.0?missed_alpha:opacity)*ghost_fade*(ssrg_warp.x>0.5?1.0:smoothstep(-60.0,-55.0,world_z));
	if(note_brightness_applies) ALBEDO*=synk_note_brightness;
}
