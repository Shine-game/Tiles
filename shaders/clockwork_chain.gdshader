shader_type canvas_item;
render_mode unshaded, blend_mix;
uniform sampler2D link_art : filter_linear, repeat_disable;
uniform float link_scale = 1.0;
uniform float progress = 1.0;
uniform float travel = 0.0;
uniform bool reverse_run = false;
uniform float visibility = 1.0;
void fragment() {
    float x = UV.x * 256.0;
    float pitch = 29.0 * link_scale;
    float canvas = 64.0 * link_scale;
    float phase = mod(travel, pitch);
    // Anchor each run at its own source axle. This keeps assembly symmetric
    // even when the larger pitch no longer divides the axle separation.
    float from_start = reverse_run ? 256.0 - x : x;
    float nearest = floor((from_start - phase) / pitch + 0.5);
    float steps = ceil(256.0 / pitch);
    vec4 result = vec4(0.0);
    for (int i = -1; i <= 1; i++) {
        float slot = nearest + float(i);
        float along = slot * pitch + phase;
        float center = reverse_run ? 256.0 - along : along;
        bool assembled = progress >= 0.999 || along <= floor(progress * steps) * pitch;
        // Keep artwork orientation/light direction unchanged on both runs.
        vec2 uv = vec2((x - center + canvas * 0.5) / canvas, UV.y);
        if (assembled && uv.x >= 0.0 && uv.x <= 1.0) {
            vec4 ink = texture(link_art, uv);
            float a = ink.a + result.a * (1.0 - ink.a);
            result.rgb = (ink.rgb * ink.a + result.rgb * result.a * (1.0 - ink.a)) / max(a, 0.00001);
            result.a = a;
        }
    }
    COLOR = vec4(result.rgb, result.a * visibility * step(0.0001, progress));
}
