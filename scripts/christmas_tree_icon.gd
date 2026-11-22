extends Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	draw_rect(Rect2(size * Vector2(0.44, 0.72), size * Vector2(0.12, 0.22)), Color("#865638"))
	for i in range(3):
		var y := 0.07 + i * 0.20
		var half_width := 0.24 + i * 0.09
		draw_colored_polygon(PackedVector2Array([
			size * Vector2(0.5, y),
			size * Vector2(0.5 + half_width, y + 0.34),
			size * Vector2(0.5 - half_width, y + 0.34),
		]), Color("#286348"))
