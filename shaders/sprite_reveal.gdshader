shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform sampler2D reveal_field : filter_linear, repeat_disable;
uniform bool time_field = false;
uniform float reveal_progress = 0.0;
uniform float visual_clock = 0.0;
uniform float field_start = 0.0;
uniform float soft_seconds = 0.0;
uniform float edge_feather = 0.01;
uniform bool recolor = false;
uniform vec4 palette_source : source_color = vec4(1.0);
uniform vec4 palette_target : source_color = vec4(1.0);
varying vec4 vertex_tint;

vec3 rgb_to_hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 0.000001)), d / (q.x + 0.000001), q.x);
}
vec3 hsv_to_rgb(vec3 c) {
    vec3 p = abs(fract(c.xxx + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
    return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

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
    if (recolor) {
        vec3 source = rgb_to_hsv(palette_source.rgb);
        vec3 target = rgb_to_hsv(palette_target.rgb);
        vec3 color = rgb_to_hsv(art.rgb);
        color.x = fract(color.x + target.x - source.x);
        color.y = clamp(color.y * target.y / max(source.y, 0.01), 0.0, 1.0);
        color.z = clamp(color.z * target.z / max(source.z, 0.01), 0.0, 1.0);
        art.rgb = hsv_to_rgb(color);
    }
    COLOR = vec4(art.rgb, art.a * visible);
}
