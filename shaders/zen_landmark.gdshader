shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/tile_surface.gdshaderinc"

uniform vec2 artwork_origin = vec2(0.0);
uniform vec2 artwork_pixels = vec2(512.0);
uniform float screen_pixel = 1.0;
varying vec4 vertex_tint;
void vertex() { vertex_tint = COLOR; }

void fragment() {
    vec4 artwork = texture(TEXTURE, UV) * vertex_tint;
    vec2 p = artwork_origin + UV * artwork_pixels;
    artwork.a *= surface_coverage(surface_distance(p, 0.0), screen_pixel);
    // Preserve the supplied lighting; do not apply sand relief or rotate it.
    COLOR = artwork;
}
