shader_type canvas_item;
render_mode unshaded, blend_mix;
uniform sampler2D link_art : filter_linear, repeat_disable;
uniform float progress = 1.0;
uniform float travel = 0.0;
uniform bool reverse_run = false;
uniform float visibility = 1.0;
void fragment() {
    float x = UV.x * 256.0;
    float phase = (reverse_run ? -1.0 : 1.0) * mod(travel, 29.0);
    float nearest = floor((x - phase) / 29.0 + 0.5);
    vec4 result = vec4(0.0);
    for (int i = -1; i <= 1; i++) {
        float slot = nearest + float(i);
        float center = slot * 29.0 + phase;
        float distance_from_start = reverse_run ? 256.0 - center : center;
        bool assembled = progress >= 0.999 || distance_from_start <= floor(progress * 9.0) * 29.0;
        vec2 uv = vec2((x - center + 32.0) / 64.0, UV.y);
        if (assembled && uv.x >= 0.0 && uv.x <= 1.0) {
            vec4 ink = texture(link_art, uv);
            float a = ink.a + result.a * (1.0 - ink.a);
            result.rgb = (ink.rgb * ink.a + result.rgb * result.a * (1.0 - ink.a)) / max(a, 0.00001);
            result.a = a;
        }
    }
    COLOR = vec4(result.rgb, result.a * visibility * step(0.0001, progress));
}
