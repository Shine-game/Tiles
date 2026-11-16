shader_type canvas_item;
render_mode unshaded;

uniform sampler2D stack_artwork : source_color, repeat_disable, filter_linear_mipmap;
uniform sampler2D bamboo_artwork : source_color, repeat_disable, filter_linear_mipmap;
uniform float stack_progress = 0.0;
uniform float bamboo_progress = 0.0;
varying vec4 vertex_tint;
void vertex() { vertex_tint = COLOR; }

vec4 blend_stage(vec4 before, vec4 after, float progress) {
    // Interpolate premultiplied coverage to retain clean antialiased edges.
    float alpha = mix(before.a, after.a, progress);
    vec3 color = mix(before.rgb * before.a, after.rgb * after.a, progress);
    return vec4(color / max(alpha, 0.00001), alpha);
}

void fragment() {
    // The supplied flattened stages already share their base stone pixels
    // and put bamboo behind the cairn. Blend only once on their fixed canvas;
    // unchanged base pixels stay unchanged while each addition appears.
    vec4 base = texture(TEXTURE, UV);
    vec4 stack = blend_stage(base, texture(stack_artwork, UV), stack_progress);
    COLOR = blend_stage(stack, texture(bamboo_artwork, UV), bamboo_progress) * vertex_tint;
}
