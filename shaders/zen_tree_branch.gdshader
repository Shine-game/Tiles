shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/tile_surface.gdshaderinc"
uniform vec4 uv_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec2 image_size = vec2(256.0);
uniform vec2 pivot = vec2(0.0);
uniform vec2 branch_root = vec2(0.0);
uniform float branch_scale = 1.0;
uniform float branch_angle = 0.0;
uniform float progress = 1.0;
uniform float screen_pixel = 1.0;
void fragment() {
    vec2 local_uv = (UV - uv_rect.xy) / uv_rect.zw;
    vec2 local = local_uv * image_size - pivot;
    float c = cos(branch_angle);
    float s = sin(branch_angle);
    vec2 p = branch_root + branch_scale * vec2(c * local.x - s * local.y, s * local.x + c * local.y);
    vec4 art = texture(TEXTURE, UV);
    // Remove semi-transparent sheet haze/fringes at runtime; masters stay intact.
    art.a = smoothstep(0.82, 0.98, art.a);
    float reveal = 1.0 - smoothstep(progress * 1.10 - 0.10, progress * 1.10, local_uv.x);
    art.a *= reveal * surface_coverage(surface_distance(p, 0.0), screen_pixel);
    COLOR = art;
}
