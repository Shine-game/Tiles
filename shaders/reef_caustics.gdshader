shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec2 cell_origin = vec2(0.0);
uniform float cell_pixels = 64.0;
uniform vec2 rect_pixels = vec2(640.0);
// A fixed phase supports native render checks; gameplay uses shader time.
uniform float time_override = -1.0;

vec2 site_hash(vec2 site) {
    return fract(sin(vec2(dot(site, vec2(127.1, 311.7)),
        dot(site, vec2(269.5, 183.3)))) * 43758.5453);
}

void fragment() {
    vec2 board = (UV * rect_pixels - cell_origin) / cell_pixels;
    float t = (time_override < 0.0 ? TIME : time_override) * 1.25;
    // Pools are roughly 1.5–2 board squares wide, as in the reference.
    // A continuous warped domain curves their shared bright boundaries.
    vec2 p = board * 0.62;
    p += vec2(sin(board.y * 0.83 + t * 0.67),
        cos(board.x * 0.76 - t * 0.73)) * 0.22;
    p += vec2(sin(board.x * 1.61 + board.y * 1.23 - t * 0.81),
        sin(board.y * 1.47 - board.x * 1.13 + t * 0.69)) * 0.065;
    vec2 cell = floor(p);
    vec2 local = fract(p);
    float first = 100000.0;
    float second = 100000.0;
    vec2 nearest = vec2(0.0);
    vec2 runner_up = vec2(0.0);
    // Sites oscillate continuously in place over ~5–6 seconds, rather than
    // slowly translating stripes. One shared field covers the entire board.
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 offset = vec2(float(x), float(y));
            vec2 random = site_hash(cell + offset);
            vec2 site = vec2(0.5) + (random - vec2(0.5)) * 0.40;
            site += sin(vec2(t, t * 0.84) + random * 6.2831853) * 0.19;
            vec2 delta = offset + site - local;
            float distance_squared = dot(delta, delta);
            if (distance_squared < first) {
                second = first;
                runner_up = nearest;
                first = distance_squared;
                nearest = delta;
            } else if (distance_squared < second) {
                second = distance_squared;
                runner_up = delta;
            }
        }
    }
    float edge = (second - first) / max(2.0 * length(runner_up - nearest), 0.0001);
    float filament = 1.0 - smoothstep(0.004, 0.020, edge);
    float halo = 1.0 - smoothstep(0.020, 0.100, edge);
    float light_alpha = filament * 0.36 + halo * 0.15;
    float shade_alpha = (0.065 + 0.095 * smoothstep(0.10, 0.48, edge)) * (1.0 - halo);
    float alpha = light_alpha + shade_alpha;
    vec3 illumination = (vec3(0.92, 0.995, 0.98) * light_alpha
        + vec3(0.25, 0.55, 0.57) * shade_alpha) / max(alpha, 0.00001);
    COLOR = vec4(illumination, alpha);
}
