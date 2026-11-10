shader_type canvas_item;
render_mode unshaded, blend_mix;
uniform float rise = 1.0;
uniform float turn_angle = 0.0;
uniform float height_source = 16.0;
varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() {
    // Keep the face/pivot fixed. A shaded vertical flank grows beneath it;
    // inverse-rotated sampling keeps the depth direction fixed on screen.
    vec2 down = vec2(sin(turn_angle), cos(turn_angle)) * height_source * rise * TEXTURE_PIXEL_SIZE;
    vec4 face = texture(TEXTURE, UV);
    vec4 lower = texture(TEXTURE, UV - down);
    float wall = lower.a * (1.0 - face.a);
    float alpha = face.a + wall;
    vec3 rgb = (face.rgb * face.a + lower.rgb * 0.62 * wall) / max(alpha, 0.00001);
    COLOR = vec4(rgb * tint.rgb, alpha * rise * tint.a);
}
