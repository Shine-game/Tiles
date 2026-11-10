shader_type canvas_item;
render_mode unshaded, blend_mix;
#include "res://shaders/tile_surface.gdshaderinc"

uniform bool metal_surface = false;
uniform sampler2D metal_lip : filter_linear, repeat_disable;
uniform vec2 cell_center = vec2(0.5);
uniform float quarter_turn = 0.0;
uniform float screen_pixel = 4.0;

varying vec4 vertex_tint;

void vertex() {
    vertex_tint = COLOR;
}

void fragment() {
    vec2 local = (UV - vec2(0.5)) * cell_pixels;
    float angle = quarter_turn * 1.57079632679;
    vec2 rotated = vec2(cos(angle) * local.x - sin(angle) * local.y, sin(angle) * local.x + cos(angle) * local.y);
    vec2 p = cell_center * cell_pixels + rotated;
    float distance_to_surface = surface_distance(p, 0.0);
    vec4 artwork = texture(TEXTURE, UV) * vertex_tint;
    artwork.rgb = surface_lip(artwork.rgb, distance_to_surface, screen_pixel);
    if (metal_surface && distance_to_surface > -2.0 * screen_pixel) {
        vec4 lip = texture(metal_lip, vec2(0.5, clamp(-distance_to_surface / (2.0 * screen_pixel), 0.0, 1.0)));
        artwork.rgb = mix(artwork.rgb, lip.rgb, lip.a);
    }
    artwork.a *= surface_coverage(distance_to_surface, screen_pixel);
    COLOR = artwork;
}
