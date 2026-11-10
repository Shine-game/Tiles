// Shared geometry for incoming slabs, occupied ground, and textured top faces.
uniform sampler2D occupancy_mask : filter_nearest, repeat_disable;
uniform int grid_size = 9;
uniform float cell_pixels = 64.0;
uniform float corner_ratio = 0.16;

float occupied_cell(vec2 cell) {
    if (cell.x < 0.0 || cell.y < 0.0 || cell.x >= float(grid_size) || cell.y >= float(grid_size)) {
        return 0.0;
    }
    return step(0.5, texture(occupancy_mask, (cell + vec2(0.5)) / float(grid_size)).r);
}

float slab_cell_distance(vec2 p, vec2 cell, float extrusion) {
    vec2 local = p - (cell + vec2(0.5)) * cell_pixels - vec2(0.0, extrusion * 0.5);
    vec2 direction = vec2(local.x < 0.0 ? -1.0 : 1.0, local.y < 0.0 ? -1.0 : 1.0);
    // Rounding belongs only to convex exposed corners. Side neighbors fuse
    // completely, including across colors; diagonal contacts remain separate.
    float radius = cell_pixels * corner_ratio;
    radius *= (1.0 - occupied_cell(cell + vec2(direction.x, 0.0)));
    radius *= (1.0 - occupied_cell(cell + vec2(0.0, direction.y)));
    vec2 q = abs(local) - vec2(cell_pixels * 0.5, (cell_pixels + extrusion) * 0.5) + vec2(radius);
    return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
}

float surface_distance(vec2 p, float extrusion) {
    float distance_to_surface = 100000.0;
    vec2 cell = floor(p / cell_pixels);
    if (extrusion == 0.0 && occupied_cell(cell) > 0.5 && slab_cell_distance(p, cell, 0.0) <= 0.0) {
        // Cell-box SDFs contain false zeroes on shared edges. Measure only
        // exposed boundaries inside the union, so no seam or lip survives fusion.
        vec2 local = p - cell * cell_pixels;
        float inside = 100000.0;
        if (occupied_cell(cell + vec2(-1.0, 0.0)) < 0.5) { inside = min(inside, local.x); }
        if (occupied_cell(cell + vec2(1.0, 0.0)) < 0.5) { inside = min(inside, cell_pixels - local.x); }
        if (occupied_cell(cell + vec2(0.0, -1.0)) < 0.5) { inside = min(inside, local.y); }
        if (occupied_cell(cell + vec2(0.0, 1.0)) < 0.5) { inside = min(inside, cell_pixels - local.y); }
        vec2 direction = vec2(local.x < cell_pixels * 0.5 ? -1.0 : 1.0, local.y < cell_pixels * 0.5 ? -1.0 : 1.0);
        float radius = cell_pixels * corner_ratio;
        if (occupied_cell(cell + vec2(direction.x, 0.0)) < 0.5 && occupied_cell(cell + vec2(0.0, direction.y)) < 0.5
                && abs(local.x - cell_pixels * 0.5) > cell_pixels * 0.5 - radius
                && abs(local.y - cell_pixels * 0.5) > cell_pixels * 0.5 - radius) {
            inside = min(inside, -slab_cell_distance(p, cell, 0.0));
        }
        return -inside;
    }
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 neighbor = cell + vec2(float(x), float(y));
            if (occupied_cell(neighbor) > 0.5) {
                distance_to_surface = min(distance_to_surface, slab_cell_distance(p, neighbor, extrusion));
            }
        }
    }
    return distance_to_surface;
}

float surface_coverage(float distance_to_surface, float pixel) {
    return 1.0 - smoothstep(0.0, pixel, distance_to_surface);
}

vec3 surface_lip(vec3 ink, float distance_to_surface, float pixel) {
    float lip = 0.30 * smoothstep(-1.25 * pixel, -0.15 * pixel, distance_to_surface);
    return mix(ink, vec3(1.0), lip);
}
