shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec2 cell_origin = vec2(0.0);
uniform float cell_pixels = 64.0;
uniform vec2 rect_pixels = vec2(640.0);
// Native render checks can freeze a phase. Normal gameplay uses shader time,
// independent of the board's placement/growth processing.
uniform float time_override = -1.0;

void fragment() {
    vec2 p = (UV * rect_pixels - cell_origin) / cell_pixels;
    float t = (time_override < 0.0 ? TIME : time_override) * 0.16;
    // Slowly refracted broad bands, shared over every structure and empty cell.
    vec2 flow = p + vec2(sin(p.y * 0.53 + t) * 0.32, cos(p.x * 0.47 - t * 0.8) * 0.28);
    float a = sin(flow.x * 1.45 + flow.y * 1.08 + t * 0.62);
    float b = sin(flow.x * -1.02 + flow.y * 1.61 - t * 0.75 + 1.8);
    float c = sin(flow.x * 0.79 - flow.y * 0.66 + t * 0.39 + 0.5);
    float folded = a + b * 0.65 + c * 0.35;
    float light = exp(-folded * folded * 7.0);
    float second = exp(-pow(a * 0.62 - b + c * 0.30, 2.0) * 9.0);
    // At most ~2% added light. Soft edges and slow drift preserve legibility.
    COLOR = vec4(vec3(0.78, 0.96, 0.93), (light * 0.013 + second * 0.007));
}
