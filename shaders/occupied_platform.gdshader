shader_type canvas_item;
render_mode unshaded, blend_mix;
#include "res://shaders/tile_surface.gdshaderinc"

uniform float depth_pixels = 6.0;
uniform float margin_pixels = 13.0;
uniform vec2 rect_pixels = vec2(608.0);
uniform vec4 ground_color : source_color = vec4(0.92, 0.84, 0.69, 1.0);

void fragment() {
    vec2 p = UV * rect_pixels - vec2(margin_pixels);
    float top_distance = surface_distance(p, 0.0);
    if (top_distance <= 0.0) {
        // Opaque tops cover the wall and shadow; avoid their neighborhood
        // searches for occupied interiors, including dense mobile boards.
        COLOR = vec4(surface_lip(ground_color.rgb, top_distance, 1.0), 1.0);
    } else {
        float slab_distance = surface_distance(p, depth_pixels);
        float top = surface_coverage(top_distance, 1.0);
        float slab = surface_coverage(slab_distance, 1.0);
        // Same offset, softness and contact shading for every tile surface.
        vec2 shadow_offset = vec2(depth_pixels * 0.25, depth_pixels * 0.7);
        float shadow_distance = surface_distance(p - shadow_offset, depth_pixels);
        float shadow = 0.18 * (1.0 - smoothstep(0.0, max(1.0, depth_pixels), shadow_distance));
        vec4 result = vec4(vec3(0.0), shadow);
        float wall_t = clamp(top_distance / max(depth_pixels, 0.001), 0.0, 1.0);
        vec3 wall = ground_color.rgb * mix(0.84, 0.75, smoothstep(0.0, 1.0, wall_t));
        float alpha = slab + shadow * (1.0 - slab);
        vec3 rgb = wall * slab / max(alpha, 0.00001);
        result = vec4(rgb, alpha);
        vec3 top_ink = surface_lip(ground_color.rgb, top_distance, 1.0);
        alpha = top + result.a * (1.0 - top);
        rgb = (top_ink * top + result.rgb * result.a * (1.0 - top)) / max(alpha, 0.00001);
        COLOR = vec4(rgb, alpha);
    }
}
