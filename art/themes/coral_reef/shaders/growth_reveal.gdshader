shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform sampler2D artwork : source_color, filter_linear, repeat_disable;
uniform sampler2D growth_mask : filter_linear, repeat_disable;
uniform float clock_seconds = 0.0;
uniform float stroke_seconds = 0.1;
uniform float start_at_zero = 0.0;
uniform float start_at_one = 0.0;
uniform bool front_zero_enabled = true;
uniform bool front_one_enabled = false;
uniform float soft_front_seconds = 0.035;
uniform bool layer_enabled = true;
uniform bool force_complete = false;
varying vec4 vertex_tint;

void vertex() {
    vertex_tint = COLOR;
}

void fragment() {
    vec4 pixel = texture(artwork, UV) * vertex_tint;
    float visible = 0.0;
    if (layer_enabled) {
        if (force_complete) {
            visible = 1.0;
        } else {
            float u = texture(growth_mask, UV).r;
            float duration = max(stroke_seconds, 0.00001);
            float t0 = 1000000000.0;
            float t1 = 1000000000.0;
            if (front_zero_enabled) {
                t0 = start_at_zero + u * duration;
            }
            if (front_one_enabled) {
                t1 = start_at_one + (1.0 - u) * duration;
            }
            float arrival = min(t0, t1);
            visible = smoothstep(0.0, max(soft_front_seconds, 0.00001),
                                 clock_seconds - arrival);
        }
    }
    pixel.a *= visible;
    COLOR = pixel;
}
