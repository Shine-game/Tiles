shader_type canvas_item;
render_mode unshaded;
uniform bool protect_rock = false;
uniform float amount = 1.0;
uniform int direction = 0;
void fragment() {
    float inward = direction == 0 ? UV.y : (direction == 1 ? 1.0 - UV.x : (direction == 2 ? 1.0 - UV.y : UV.x));
    float reveal = 1.0 - smoothstep(amount * 1.1 - 0.1, amount * 1.1, inward);
    float coverage = texture(TEXTURE, UV).r * (protect_rock ? amount : reveal);
    COLOR = vec4(vec3(protect_rock ? 0.0 : 1.0), coverage);
}
