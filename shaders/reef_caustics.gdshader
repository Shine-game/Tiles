shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec2 cell_origin = vec2(0.0);
uniform float cell_pixels = 64.0;
uniform vec2 rect_pixels = vec2(640.0);
// A fixed phase supports native render checks; gameplay uses shader time.
uniform float time_override = -1.0;

vec2 site_hash(vec2 site) {
    // Algebraic hash avoids extra trigonometric work for every candidate.
    vec3 p = fract(vec3(site.x, site.y, site.x) * vec3(0.1031, 0.1030, 0.0973));
    p += dot(p, p.yzx + vec3(33.33));
    return fract((p.xx + p.yz) * p.zy);
}

void consider_site(vec2 delta, float bias, inout float first, inout float second,
        inout vec2 nearest, inout vec2 runner_up) {
    float score = dot(delta, delta) + bias;
    if (score < first) {
        second = first;
        runner_up = nearest;
        first = score;
        nearest = delta;
    } else if (score < second) {
        second = score;
        runner_up = delta;
    }
}

void fragment() {
    vec2 board = (UV * rect_pixels - cell_origin) / cell_pixels;
    float t = (time_override < 0.0 ? TIME : time_override) * 0.95;
    // Large pools keep the reference scale; intermittent secondary sites
    // split selected pools into smaller ones.
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
    vec2 current_x = vec2(sin(t), cos(t));
    vec2 current_y = vec2(sin(t * 0.84), -cos(t * 0.84));
    vec2 lifecycle = vec2(sin(t * 0.45), cos(t * 0.45));
    // Power-diagram sites change effective area continuously. Secondary sites
    // emerge at a point, grow into small pools, then shrink away, allowing
    // genuine splits/merges without popping or crossfading two unrelated webs.
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 offset = vec2(float(x), float(y));
            vec2 identity = cell + offset;
            vec2 random = site_hash(identity);
            vec2 direction = normalize(random - vec2(0.5) + vec2(0.0001));
            vec2 site = vec2(0.5) + (random - vec2(0.5)) * 0.40;
            site += vec2(dot(direction, current_x), dot(direction, current_y)) * 0.19;
            consider_site(offset + site - local, 0.0, first, second, nearest, runner_up);

            vec2 extra_random = site_hash(identity + vec2(37.2, 19.4));
            vec2 extra_direction = normalize(extra_random - vec2(0.5) + vec2(0.0001));
            vec2 extra_site = vec2(0.5) + (extra_random - vec2(0.5)) * 0.76;
            extra_site += vec2(dot(extra_direction, current_y), dot(extra_direction, current_x)) * 0.10;
            float region = sin(dot(identity, vec2(0.43, 0.37)) + t * 0.30);
            float life = region * 0.62 + dot(extra_direction, lifecycle) * 0.38;
            float emergence = smoothstep(-0.25, 0.75, life);
            float bias = 1.25 * pow(1.0 - emergence, 2.0) + 0.005;
            consider_site(offset + extra_site - local, bias, first, second, nearest, runner_up);
        }
    }
    float edge = (second - first) / max(2.0 * length(runner_up - nearest), 0.0001);
    float filament = 1.0 - smoothstep(0.004, 0.020, edge);
    float halo = 1.0 - smoothstep(0.020, 0.100, edge);
    float light_alpha = filament * 0.27 + halo * 0.11;
    float shade_alpha = (0.050 + 0.070 * smoothstep(0.10, 0.48, edge)) * (1.0 - halo);
    float alpha = light_alpha + shade_alpha;
    vec3 illumination = (vec3(0.92, 0.995, 0.98) * light_alpha
        + vec3(0.25, 0.55, 0.57) * shade_alpha) / max(alpha, 0.00001);
    COLOR = vec4(illumination, alpha);
}
