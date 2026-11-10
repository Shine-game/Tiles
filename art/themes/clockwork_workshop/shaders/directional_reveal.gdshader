shader_type canvas_item;
render_mode blend_mix;
uniform sampler2D growth_field : filter_linear, repeat_disable;
uniform float visual_clock = 0.0;
uniform float start_core = 0.0;
uniform float start_edge = 0.0;
uniform bool core_enabled = true;
uniform bool edge_enabled = false;
uniform float travel_seconds = 0.20;
uniform float reveal_tail_seconds = 0.035;
void fragment() {
    vec4 art = texture(TEXTURE, UV);
    float u = texture(growth_field, UV).r;
    float arrival = 1e15;
    if (core_enabled) arrival = min(arrival, start_core + u * travel_seconds);
    if (edge_enabled) arrival = min(arrival, start_edge + (1.0 - u) * travel_seconds);
    float visible = smoothstep(arrival, arrival + max(reveal_tail_seconds, 0.0001), visual_clock);
    COLOR = vec4(art.rgb, art.a * visible);
}
