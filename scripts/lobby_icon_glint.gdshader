shader_type canvas_item;
uniform float clock = 0.0;
uniform float engagement = 0.0;
void fragment() {
    vec4 source = texture(TEXTURE, UV);
    float sweep = fract(clock * 0.19) * 2.0 - 0.5;
    float glint = exp(-pow((UV.x + UV.y * 0.35 - sweep) * 16.0, 2.0));
    source.rgb += vec3(0.25, 0.65, 0.75) * glint * (0.23 + engagement * 0.22);
    COLOR = source * COLOR;
}
