shader_type canvas_item;

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 finger = texture(TEXTURE, UV);
	COLOR = vec4(finger.grb, finger.a) * tint;
}
