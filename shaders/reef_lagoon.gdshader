shader_type canvas_item;
render_mode unshaded, blend_mix;

void fragment() {
    // One broad basin of color over the entire board, without tiled noise.
    vec2 p = UV;
    float basin = smoothstep(0.05, 1.1, length((p - vec2(0.38, 0.30)) * vec2(0.85, 1.0)));
    float drift = sin(p.x * 2.4 + p.y * 1.7) * 0.5 + 0.5;
    vec3 shallow = vec3(0.895, 0.959, 0.944);
    vec3 deep = vec3(0.825, 0.918, 0.912);
    COLOR = vec4(mix(shallow, deep, clamp(basin * 0.78 + drift * 0.10, 0.0, 1.0)), 1.0);
}
