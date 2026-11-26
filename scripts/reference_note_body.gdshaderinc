uniform sampler2D artwork : source_color, filter_linear_mipmap, repeat_disable;
uniform float hue_shift = 0.0;
uniform float saturation_scale = 1.0;
uniform float value_scale = 1.0;
uniform float opacity = 1.0;
uniform float ghost_fade = 1.0;
uniform float desaturate = 0.0;
uniform vec4 source_tint : source_color = vec4(1.0);
uniform float clip_z = 1000.0;
// SSRG Playables: falling notes play a 6-frame glow loop like a sprite sequence (white-hot
// centre and halo down to the plain colour, then again), and stay hot over the last
// `glow_distance` units before the judgement line.
uniform bool approach_glow = false;
uniform float glow_distance = 7.0;
// Colour of the note's glass centre when it is not glowing (blue taps, gold holds).
uniform vec3 core_tint : source_color = vec3(0.32, 0.78, 1.0);
const float GLOW_FRAMES = 6.0;
const float GLOW_LOOPS_PER_SECOND = 2.2;
global uniform float synk_time;
varying float world_z;
varying float centre_z;
#include "res://scripts/ssrg_warp.gdshaderinc"
// world_z and centre_z stay linear track positions for clipping, fading and the glow.
void vertex(){ world_z=(MODEL_MATRIX*vec4(VERTEX,1.0)).z; centre_z=MODEL_MATRIX[3].z; VERTEX=ssrg_warp_rigid(VERTEX,MODEL_MATRIX); }
// Rotate hue only: value, saturation, white highlights and source alpha survive intact.
vec3 rgb_to_hsv(vec3 c){
    vec4 k=vec4(0.0,-1.0/3.0,2.0/3.0,-1.0);
    vec4 p=mix(vec4(c.bg,k.wz),vec4(c.gb,k.xy),step(c.b,c.g));
    vec4 q=mix(vec4(p.xyw,c.r),vec4(c.r,p.yzx),step(p.x,c.r));
    float d=q.x-min(q.w,q.y);
    return vec3(abs(q.z+(q.w-q.y)/(6.0*d+0.0000001)),d/(q.x+0.0000001),q.x);
}
vec3 hsv_to_rgb(vec3 c){
    vec3 p=abs(fract(c.xxx+vec3(0.0,2.0/3.0,1.0/3.0))*6.0-3.0);
    return c.z*mix(vec3(1.0),clamp(p-1.0,0.0,1.0),c.y);
}
// Player setting: how bright notes and their trails are (Settings > Visuals > Notes).
global uniform float synk_note_brightness;
uniform bool note_brightness_applies = true;
// Animated flick frames: the chevron above this UV row is never dimmed by the note
// brightness setting (it keeps full white like the old flick arrow); the puck below is.
uniform float full_bright_above_uv = -1.0;
// SYNK mode: notes start a little muted in the distance and grow richer, brighter and
// haloed as they come, reaching full glow at the judgment line. 0 turns it off;
// `approach_span` is how far out (track units) the build-up begins.
uniform float approach_vibrance = 0.0;
uniform float approach_span = 36.0;
// Note thickness (Settings > Visuals > Notes, SYNK mode): the quad is made taller by
// `wall` times the art's height and the note's silhouette is swept down into that space
// as a side wall, so the disc reads as a solid puck. Rows above `wall_from_uv` cast no
// wall (the flick's chevrons).
uniform float wall = 0.0;
uniform float wall_from_uv = 0.0;
#include "res://scripts/synk_note_shape.gdshaderinc"
const int WALL_STEPS = 8;
void fragment(){
    if((ssrg_warp.x>0.5?centre_z:world_z)>clip_z) discard;
    vec2 uv=vec2(UV.x,UV.y*(1.0+wall));
    // The art is read through the note shape; the plain UV keeps the mip level steady across its corners.
    vec2 flat_uv=uv;
    uv=synk_shape_uv(uv);
    vec4 art=flat_uv.y>1.0?vec4(0.0):textureGrad(artwork,uv,dFdx(flat_uv),dFdy(flat_uv));
    vec3 hsv=rgb_to_hsv(art.rgb);
    hsv.x=fract(hsv.x+hue_shift);
    hsv.y=clamp(hsv.y*saturation_scale,0.0,1.0);
    hsv.z*=value_scale;
    vec3 color=hsv_to_rgb(hsv);
    float gray=dot(color,vec3(0.299,0.587,0.114));
    float alpha=art.a;
    if(approach_glow){
        // Stepped frame 0..5 (0 = hottest), offset by position so notes do not pulse in unison.
        float frame=floor(fract(synk_time*GLOW_LOOPS_PER_SECOND+centre_z*0.031)*GLOW_FRAMES);
        float loop_heat=1.0-frame/(GLOW_FRAMES-1.0);
        float near=pow(clamp(1.0+centre_z/glow_distance,0.0,1.0),1.4);
        // Extract check: the source draws notes as plain alpha/cutout sprites (UIBatchSprite);
        // the glow lives in the frame art and a separate effects layer, not a per-note white burn.
        // So keep this synthetic glow as a gentle tint and let the authored art read through.
        float heat=max(loop_heat*0.30,near*0.40);
        float bright=dot(art.rgb,vec3(0.3,0.55,0.15));
        // Cool: the white centre takes the note's colour; hot: it burns back to white.
        float centre_mask=smoothstep(0.55,0.95,bright);
        color=mix(color,core_tint*(0.55+0.45*bright),centre_mask*(1.0-heat)*0.8);
        color=mix(color,vec3(1.0),heat*centre_mask*0.45);
        // Halo: the blurred note shape (a low mip) around the edge, white-tinted.
        float halo=textureLod(artwork,uv,4.0).a;
        float rim=heat*halo*(1.0-art.a)*0.30;
        color=mix(color,vec3(1.0),rim/max(0.001,alpha+rim));
        alpha=max(alpha,rim);
    }
    float burn=1.0;
    if(approach_vibrance>0.0){
        float coming=pow(clamp(1.0+centre_z/approach_span,0.0,1.0),1.6)*approach_vibrance;
        vec3 rich=rgb_to_hsv(color);
        rich.y=clamp(rich.y*(0.9+0.5*coming),0.0,1.0);
        rich.z=rich.z*(0.82+0.5*coming);
        color=hsv_to_rgb(rich);
        // The glassy middle of the disc fills with the note's own light.
        vec4 soft=textureLod(artwork,uv,3.0);
        float fill=coming*soft.a*(1.0-alpha)*0.55;
        // Halo: the blurred note shape spilling past its edge.
        vec4 wide=textureLod(artwork,uv,5.0);
        float halo=coming*wide.a*(1.0-art.a)*0.5;
        float glow=clamp(fill+halo,0.0,1.0);
        color=mix(color,soft.rgb*1.25,glow/max(0.001,alpha+glow));
        alpha=max(alpha,glow);
        // Near the line the note is never dimmed by the brightness setting.
        burn=coming;
    }
    if(wall>0.0){
        // Deepest layer first, so nearer layers of the wall cover it; the top face goes on last.
        vec3 side=vec3(0.0); float side_alpha=0.0;
        for(int i=WALL_STEPS;i>=1;i--){
            float k=float(i)/float(WALL_STEPS);
            vec2 at=vec2(flat_uv.x,flat_uv.y-wall*k);
            if(at.y<wall_from_uv || at.y>1.0) continue;
            vec4 layer=textureLod(artwork,synk_shape_uv(at),1.0);
            float solid=smoothstep(0.55,0.85,layer.a);
            // Darker toward the bottom, with a lit lower lip.
            vec3 shade=i==WALL_STEPS?layer.rgb*0.9+0.08:layer.rgb*(0.55-0.33*k);
            side=mix(side,shade,solid); side_alpha=max(side_alpha,solid*0.92);
        }
        vec3 lit=rgb_to_hsv(side); lit.x=fract(lit.x+hue_shift); side=hsv_to_rgb(lit);
        color=mix(side,color,alpha/max(0.001,alpha+side_alpha*(1.0-alpha)));
        alpha=alpha+side_alpha*(1.0-alpha);
        gray=dot(color,vec3(0.299,0.587,0.114));
    }
    ALBEDO=mix(color,vec3(gray*0.52),desaturate)*source_tint.rgb;
    ALPHA=alpha*opacity*ghost_fade*source_tint.a*smoothstep(-60.0,-55.0,world_z)*ssrg_reveal(centre_z);
	if(note_brightness_applies){
		float keep=full_bright_above_uv>0.0?1.0-smoothstep(full_bright_above_uv-0.03,full_bright_above_uv,flat_uv.y):0.0;
		ALBEDO*=mix(synk_note_brightness,max(synk_note_brightness,1.0),max(keep,burn*step(0.001,approach_vibrance)));
	}
}
