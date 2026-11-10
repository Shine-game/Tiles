shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform sampler2D occupancy_mask : filter_nearest, repeat_disable;
uniform int grid_size = 9;
uniform float cell_pixels = 64.0;
uniform float depth_pixels = 6.0;
uniform float margin_pixels = 4.0;
uniform vec2 rect_pixels = vec2(584.0);
uniform vec4 ground_color : source_color = vec4(0.92, 0.84, 0.69, 1.0);

float occupied_cell(vec2 cell) {
    if (cell.x < 0.0 || cell.y < 0.0 || cell.x >= float(grid_size) || cell.y >= float(grid_size)) {
        return 0.0;
    }
    return step(0.5, texture(occupancy_mask, (cell + vec2(0.5)) / float(grid_size)).r);
}

float occupied_point(vec2 point) {
    return occupied_cell(floor(point / cell_pixels));
}

float rectangle_distance(vec2 point, vec2 cell) {
    vec2 q = abs(point - (cell + vec2(0.5)) * cell_pixels) - vec2(cell_pixels * 0.5);
    return length(max(q, vec2(0.0)));
}

vec4 platform_edge(vec2 p) {
    // Top interiors are supplied by the existing ground textures above us.
    // Avoid distance/shadow work where this shader will be fully covered.
    if (occupied_point(p) > 0.5) {
        return vec4(0.0);
    }
    float side = occupied_point(p - vec2(0.0, depth_pixels));
    float top_distance = 100000.0;
    float base_distance = 100000.0;
    vec2 cell = floor(p / cell_pixels);
    // The shadow/rim are narrower than a cell. A local 3x3 neighborhood
    // gives exact union distances within their support, including hole edges.
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 neighbor = cell + vec2(float(x), float(y));
            if (occupied_cell(neighbor) > 0.5) {
                top_distance = min(top_distance, rectangle_distance(p, neighbor));
                base_distance = min(base_distance, rectangle_distance(p - vec2(0.0, depth_pixels), neighbor));
            }
        }
    }
    float shadow_width = max(0.85, cell_pixels * 0.035);
    float shadow_alpha = 0.14 * (1.0 - smoothstep(0.0, shadow_width, base_distance));
    vec4 result = vec4(ground_color.rgb * 0.28, shadow_alpha);
    if (side > 0.5) {
        float boundary = (floor((p.y - depth_pixels) / cell_pixels) + 1.0) * cell_pixels;
        float t = clamp((p.y - boundary) / max(depth_pixels, 0.001), 0.0, 1.0);
        result = vec4(ground_color.rgb * mix(0.94, 0.79, smoothstep(0.0, 1.0, t)), 1.0);
    }
    {
        // Place the lip just outside the top's footprint so opaque ground
        // textures above this shader cannot bury it. Never outline shared edges.
        float lip = 0.72 * (1.0 - smoothstep(0.0, 0.70, top_distance));
        vec3 lip_color = mix(ground_color.rgb, vec3(1.0), 0.48);
        float alpha = lip + result.a * (1.0 - lip);
        vec3 rgb = (lip_color * lip + result.rgb * result.a * (1.0 - lip)) / max(alpha, 0.00001);
        result = vec4(rgb, alpha);
    }
    return result;
}

void fragment() {
    // Display coordinates relative to the raised top's first cell corner.
    COLOR = platform_edge(UV * rect_pixels - vec2(margin_pixels));
}
