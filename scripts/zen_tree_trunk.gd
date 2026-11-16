extends Node2D
var thickness := 20.0
var progress := 1.0
func _draw() -> void:
	# Top-down woody hub with tapered shoulders, not an upright tree silhouette.
	var w := thickness * progress
	if w < 0.1: return
	var shape := PackedVector2Array([Vector2(-0.46, 0.40), Vector2(-0.62, -0.12), Vector2(-0.28, -0.65), Vector2(0.08, -0.76), Vector2(0.59, -0.28), Vector2(0.48, 0.30), Vector2(0.10, 0.62)])
	for i in range(shape.size()): shape[i] *= w
	draw_colored_polygon(shape, Color("5a4435"))
	draw_line(Vector2(-0.20, 0.34) * w, Vector2(0.15, -0.52) * w, Color("96785a"), maxf(1.5, w * 0.17), true)
	draw_line(Vector2(0.23, 0.30) * w, Vector2(-0.18, -0.44) * w, Color("72583f"), maxf(1.0, w * 0.09), true)
