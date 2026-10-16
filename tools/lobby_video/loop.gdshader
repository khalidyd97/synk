shader_type canvas_item;

// Original concert-light lobby loop. All time terms are periodic over twelve seconds.
uniform float phase = 0.0;
const float ASPECT = 1.7777778;

float hash(float p) { return fract(sin(p * 127.1) * 43758.5453); }
float glow(vec2 p, vec2 center, vec2 radius) {
    vec2 d = (p - center) / radius;
    return exp(-dot(d, d));
}

void fragment() {
    float t = TAU * phase;
    vec2 p = UV * vec2(ASPECT, 1.0);
    vec3 blue = vec3(0.19, 0.38, 0.72);
    vec3 rose = vec3(0.80, 0.29, 0.40);
    vec3 gold = vec3(0.98, 0.70, 0.39);
    vec3 color = mix(vec3(0.019, 0.028, 0.062), vec3(0.045, 0.055, 0.11), UV.y);

    // Broad, soft studio washes, with restrained movement behind the controls.
    color += blue * glow(p, vec2(0.25 + 0.07 * sin(t), 0.38), vec2(0.58, 0.55)) * 0.30;
    color += rose * glow(p, vec2(1.52 + 0.08 * cos(t), 0.40), vec2(0.65, 0.62)) * 0.28;
    color += gold * glow(p, vec2(0.93, 0.71), vec2(0.74, 0.13)) * 0.065;

    // Defocused LED wall: soft points, rather than a busy sharp grid.
    for (int row = 0; row < 7; row++) {
        for (int col = 0; col < 20; col++) {
            float id = float(row * 20 + col);
            vec2 light_pos = vec2(0.04 + float(col) * 0.089, 0.25 + float(row) * 0.063);
            float wave = 0.5 + 0.5 * sin(t + float(col) * 0.34 + float(row) * 0.58);
            float strength = 0.018 + 0.045 * pow(wave, 3.0);
            vec3 hue = mix(blue, rose, light_pos.x / ASPECT);
            color += hue * glow(p, light_pos, vec2(0.008 + hash(id) * 0.003)) * strength;
        }
    }

    // Slowly panning overhead spotlights, each with a broad haze and a focused core.
    for (int i = 0; i < 6; i++) {
        float fi = float(i);
        vec2 origin = vec2(0.10 + fi * 0.315, -0.06);
        float sweep = 0.24 * sin(t + fi * 1.13);
        float aim = mix(0.42, -0.42, fi / 5.0) + sweep;
        float down = max(p.y - origin.y, 0.0);
        float axis = origin.x + aim * down;
        float width = 0.018 + down * (0.09 + 0.025 * sin(t + fi));
        float distance = abs(p.x - axis);
        float cone = exp(-pow(distance / width, 2.0));
        float core = exp(-pow(distance / (width * 0.31), 2.0));
        float fade = (1.0 - smoothstep(0.55, 0.94, p.y));
        float power = 0.52 + 0.12 * sin(t + fi * 2.1);
        vec3 hue = mix(blue, gold, step(0.5, fract(fi * 0.43)));
        hue = mix(hue, rose, step(0.75, fract(fi * 0.37)));
        color += hue * (cone * 0.30 + core * 0.07) * fade * power;
        // Lens bloom remains near the top margin, clear of the song list.
        vec2 bulb = vec2(origin.x + aim * 0.10, 0.04);
        color += hue * glow(p, bulb, vec2(0.065, 0.045)) * 0.75;
        color += vec3(1.0, 0.93, 0.85) * glow(p, bulb, vec2(0.011, 0.007)) * 0.85;
    }

    // Polished stage apron: shallow curved accents and soft vertical reflections.
    float floor_mask = smoothstep(0.70, 0.77, p.y);
    float arc_y = 0.77 + 0.075 * pow((p.x - ASPECT * 0.5) / 0.9, 2.0);
    float edge = exp(-pow((p.y - arc_y) / 0.0018, 2.0));
    float edge_glow = exp(-pow((p.y - arc_y) / 0.012, 2.0));
    color += mix(blue, rose, UV.x) * (edge * 0.22 + edge_glow * 0.055);
    for (int i = 0; i < 5; i++) {
        float fi = float(i);
        float x = 0.12 + fi * 0.38 + 0.04 * sin(t + fi);
        float reflection = glow(p, vec2(x, 0.80), vec2(0.043, 0.24));
        color += mix(blue, gold, hash(fi + 17.0)) * reflection * floor_mask * 0.12;
    }

    // Large out-of-focus lenses drift in slow closed paths, mostly along the edges.
    for (int i = 0; i < 22; i++) {
        float fi = float(i);
        float h = hash(fi + 10.0);
        float radius = mix(0.013, 0.055, hash(fi + 37.0));
        vec2 center = vec2(hash(fi + 6.0) * ASPECT, hash(fi + 24.0));
        center += vec2(0.025 * sin(t + fi), 0.035 * cos(t + fi * 1.8));
        float r = length(p - center) / radius;
        float disk = 1.0 - smoothstep(0.70, 1.15, r);
        float rim = exp(-pow((r - 0.86) / 0.19, 2.0));
        float life = 0.55 + 0.45 * sin(t + fi * 2.3);
        float edge_bias = 0.3 + 0.7 * smoothstep(0.25, 0.75, abs(center.x - 0.89));
        vec3 hue = mix(blue, gold, h);
        color += hue * (disk * 0.070 + rim * 0.030) * life * edge_bias;
    }

    // A sparse foreground dust layer gives depth without distracting flashes.
    for (int i = 0; i < 36; i++) {
        float fi = float(i);
        vec2 center = vec2(hash(fi + 100.0) * ASPECT, hash(fi + 200.0));
        center += vec2(0.012 * cos(t + fi), 0.024 * sin(t + fi * 0.6));
        float sparkle = pow(0.5 + 0.5 * sin(t + fi * 1.3), 3.0);
        color += mix(blue, gold, hash(fi + 400.0)) * glow(p, center, vec2(0.0017)) * sparkle * 0.28;
    }
    float vignette = smoothstep(0.30, 1.14, length((UV - 0.5) * vec2(1.05, 1.0)));
    color *= 1.0 - vignette * 0.40;
    COLOR = vec4(color, 1.0);
}

