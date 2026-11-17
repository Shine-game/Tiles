shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform sampler2D reveal_field : filter_linear, repeat_disable;
uniform bool time_field = false;
uniform float reveal_progress = 0.0;
uniform float visual_clock = 0.0;
uniform float field_start = 0.0;
uniform float soft_seconds = 0.0;
uniform float edge_feather = 0.01;
varying vec4 vertex_tint;

void vertex() { vertex_tint = COLOR; }
void fragment() {
    vec4 art = texture(TEXTURE, UV) * vertex_tint;
    float value = texture(reveal_field, UV).r;
    float visible;
    if (time_field) {
        float arrival = field_start + value;
        visible = soft_seconds > 0.000001
            ? smoothstep(arrival, arrival + soft_seconds, visual_clock)
            : step(arrival, visual_clock);
    } else if (reveal_progress <= 0.0) {
        visible = 0.0;
    } else if (reveal_progress >= 1.0) {
        visible = 1.0;
    } else if (edge_feather > 0.0) {
        visible = 1.0 - smoothstep(reveal_progress - edge_feather, reveal_progress + edge_feather, value);
    } else {
        visible = step(value, reveal_progress);
    }
    COLOR = vec4(art.rgb, art.a * visible);
}
