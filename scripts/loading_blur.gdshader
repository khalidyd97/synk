shader_type canvas_item;

// The sharp loading artwork gradually resolves into the same moderate Gaussian
// treatment used behind gameplay. The card itself remains sharp above this layer.
uniform sampler2D blurred_art : source_color, filter_linear;
uniform float blur_amount : hint_range(0.0,1.0)=0.0;
// Keep the loading artwork readable but clearly behind the progress UI. This is
// independent of blur so the background is already dim while the chart builds.
uniform float dim_amount : hint_range(0.0,0.8)=0.48;
uniform vec4 palette_primary : source_color=vec4(0.64,0.42,1.0,1.0);
uniform vec4 palette_secondary : source_color=vec4(0.22,0.73,1.0,1.0);
uniform float artwork_palette=1.0;

void fragment(){
	vec4 sharp=texture(TEXTURE,UV);
	vec4 soft=texture(blurred_art,UV);
	float eased=smoothstep(0.0,1.0,blur_amount);
	vec3 art=mix(sharp.rgb,soft.rgb,eased);
	float edge=1.0-smoothstep(.25,.76,length(UV-vec2(.5)));
	vec3 wash=mix(palette_primary.rgb,palette_secondary.rgb,UV.x)*(.05+.07*edge)*artwork_palette;
	art=mix(art,art+wash,eased);
	art*=1.0-dim_amount;
	COLOR=vec4(art,mix(sharp.a,soft.a,eased));
}
