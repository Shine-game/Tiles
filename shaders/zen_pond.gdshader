shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/tile_surface.gdshaderinc"
uniform sampler2D flood_mask : filter_linear, repeat_disable;
uniform float screen_pixel = 1.0;
uniform float board_pixels = 2304.0;
void fragment() {
    vec2 p = UV * board_pixels;
    float water = texture(flood_mask, UV).r;
    water *= surface_coverage(surface_distance(p, 0.0), screen_pixel);
    // A single board-space reflection keeps neighboring watersheds continuous.
    // Static ripples also reproduce identically in saved artwork.
    float ripple = sin(p.x * 0.026 + sin(p.y * 0.018) * 1.8) * 0.5 + 0.5;
    float reflection = smoothstep(0.70, 0.98, ripple) * 0.045;
    vec3 ink = mix(vec3(0.34, 0.49, 0.51), vec3(0.56, 0.68, 0.68), UV.y * 0.45 + 0.25);
    vec2 pixel = vec2(1.0 / board_pixels * 3.0);
    float shore = max(0.0, water - texture(flood_mask, UV + pixel).r);
    COLOR = vec4(ink + reflection + shore * 0.10, water * 0.96);
}
