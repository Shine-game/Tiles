shader_type canvas_item;
render_mode unshaded;

uniform sampler2D sand : source_color, repeat_disable, filter_linear_mipmap;
uniform sampler2D relief_map : repeat_disable, filter_linear;
uniform vec2 cell_origin = vec2(0.0);
uniform vec2 area_cells = vec2(1.0);
uniform bool has_relief = false;
uniform bool lighting_enabled = true;
uniform vec3 light_dir = vec3(-0.45, -0.55, 0.70);
uniform float relief_height_px = 8.0;
uniform float tile_angle = 0.0;

void fragment() {
    // One board-space sand surface: mirror sampling gives matching edge values
    // without editing or rotating the supplied sand image and its baked detail.
    float c = cos(tile_angle);
    float s = sin(tile_angle);
    vec2 local = UV - vec2(0.5);
    vec2 rotated = vec2(c * local.x - s * local.y, s * local.x + c * local.y);
    vec2 world_uv = cell_origin + (rotated + vec2(0.5)) * area_cells;
    vec2 sand_uv = vec2(1.0) - abs(mod(world_uv, vec2(2.0)) - vec2(1.0));
    vec4 base = texture(sand, sand_uv);
    float illumination = 1.0;
    if (has_relief) {
        vec2 step_uv = 1.0 / vec2(textureSize(relief_map, 0));
        float hx = texture(relief_map, UV + vec2(step_uv.x, 0.0)).r
                 - texture(relief_map, UV - vec2(step_uv.x, 0.0)).r;
        float hy = texture(relief_map, UV + vec2(0.0, step_uv.y)).r
                 - texture(relief_map, UV - vec2(0.0, step_uv.y)).r;
        vec3 n = normalize(vec3(-0.5 * relief_height_px * hx,
                               -0.5 * relief_height_px * hy, 1.0));
        vec3 world_n = vec3(c * n.x - s * n.y, s * n.x + c * n.y, n.z);
        vec3 light = normalize(light_dir);
        float diffuse = max(dot(world_n, light), 0.0);
        // Normalize a level patch back to the unchanged background sand.
        if (lighting_enabled) {
            illumination = (0.78 + 0.24 * diffuse) / (0.78 + 0.24 * max(light.z, 0.0));
        }
        // Restrained cavity contrast remains readable at actual phone scale.
        float height = texture(relief_map, UV).r;
        illumination *= 1.0 - 0.12 * (1.0 - height);
    }
    COLOR = vec4(base.rgb * illumination, base.a);
}
