shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec2 cell_origin = vec2(0.0);
uniform float cell_pixels = 64.0;
uniform vec2 rect_pixels = vec2(640.0);
// Native render checks can freeze a phase. Normal gameplay uses shader time,
// independent of the board's placement/growth processing.
uniform float time_override = -1.0;

void fragment() {
    vec2 p = (UV * rect_pixels - cell_origin) / cell_pixels;
    float t = (time_override < 0.0 ? TIME : time_override) * 0.26;
    // A gently uneven water surface refracts broad traveling rows. The rows
    // curve together rather than flashing or restarting on individual cells.
    float uneven = sin(p.x * 0.75 + t * 0.55) * 0.65
        + sin(p.y * 0.60 + p.x * 0.22 - t * 0.35) * 0.24;
    float phase = p.y * 1.85 + p.x * 0.40 + uneven - t * 0.90;
    float wave = sin(phase);
    float light = smoothstep(0.05, 0.95, wave);
    float shade = smoothstep(0.05, 0.95, -wave);
    float crest = pow(max(0.0, wave), 6.0);
    float light_alpha = light * 0.20 + crest * 0.025;
    float shade_alpha = shade * 0.19;
    float alpha = light_alpha + shade_alpha;
    vec3 illumination = (vec3(0.96, 1.0, 0.98) * light_alpha
        + vec3(0.25, 0.55, 0.56) * shade_alpha) / max(alpha, 0.00001);
    COLOR = vec4(illumination, alpha);
}
