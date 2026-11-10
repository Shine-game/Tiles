shader_type canvas_item;
render_mode unshaded, blend_mix;
#include "res://shaders/tile_surface.gdshaderinc"

uniform bool metal_mode = false;
uniform sampler2D metal_wall : filter_linear, repeat_disable;
uniform sampler2D metal_lip : filter_linear, repeat_disable;
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
        vec3 face = surface_lip(ground_color.rgb, top_distance, 1.0);
        if (metal_mode && top_distance > -2.0) { vec4 lip = texture(metal_lip, vec2(0.5, clamp(-top_distance / 2.0, 0.0, 1.0))); face = mix(face, lip.rgb, lip.a); }
        COLOR = vec4(face, 1.0);
    } else {
        float slab_distance = surface_distance(p, depth_pixels);
        float top = surface_coverage(top_distance, 1.0);
        float slab = surface_coverage(slab_distance, 1.0);
        // Same offset, softness and contact shading for every tile surface.
        vec2 shadow_offset = vec2(depth_pixels * (submerged ? 0.15 : 0.25), depth_pixels * (submerged ? 0.24 : 0.7));
        float shadow_distance = surface_distance(p - shadow_offset, depth_pixels);
        float shadow = (submerged ? 0.075 : 0.18) * (1.0 - smoothstep(0.0, max(1.0, depth_pixels * (submerged ? 1.35 : 1.0)), shadow_distance));
        vec3 shadow_ink = submerged ? vec3(0.25, 0.52, 0.51) : vec3(0.0);
        vec4 result = vec4(shadow_ink, shadow);
        float wall_t = clamp(top_distance / max(depth_pixels, 0.001), 0.0, 1.0);
        vec3 wall = ground_color.rgb * mix(submerged ? 0.94 : 0.84, submerged ? 0.86 : 0.75, smoothstep(0.0, 1.0, wall_t));
        if (metal_mode) { wall = texture(metal_wall, vec2(0.5, wall_t)).rgb; }
        if (submerged) { wall = mix(wall, vec3(0.60, 0.80, 0.76), 0.18); }
        float alpha = slab + shadow * (1.0 - slab);
        vec3 rgb = (wall * slab + shadow_ink * shadow * (1.0 - slab)) / max(alpha, 0.00001);
        result = vec4(rgb, alpha);
        vec3 top_ink = surface_lip(ground_color.rgb, top_distance, 1.0);
        alpha = top + result.a * (1.0 - top);
        rgb = (top_ink * top + result.rgb * result.a * (1.0 - top)) / max(alpha, 0.00001);
        COLOR = vec4(rgb, alpha);
    }
}
